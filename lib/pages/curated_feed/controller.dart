import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/curated/curated_feed_rule.dart';
import 'package:PiliPlus/models/curated/curated_video_item_model.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/pages/search_panel/video/controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class _KeywordWorker {
  final CuratedFeedRule rule;
  late final SearchVideoController searchController;
  final List<SearchVideoItemModel> buffer = [];

  _KeywordWorker({required this.rule}) {
    searchController = SearchVideoController(
      keyword: rule.keyword,
      searchType: SearchType.video,
      tag: 'curated_${rule.id}',
    );
    searchController.titleMatchOnly.value = true;
    searchController.page = rule.currentPage;
  }

  void reset() {
    searchController.page = 1;
    searchController.isEnd = false;
    rule.currentPage = 1;
    CuratedFeedStorage.updateRulePage(rule.id, 1);
    buffer.clear();
  }

  Future<void> replenish(int targetCount) async {
    int attempts = 0;
    while (buffer.length < targetCount && attempts < 4) {
      attempts++;
      if (searchController.isEnd) {
        // 枯竭从头循环：重置到第 1 页
        searchController.page = 1;
        searchController.isEnd = false;
        rule.currentPage = 1;
        CuratedFeedStorage.updateRulePage(rule.id, 1);
      }

      final res = await searchController.customGetData();
      if (res case Success(:final response)) {
        final rawList = response.list;
        if (rawList == null || rawList.isEmpty) {
          // B 站当前轮到底，重置并在下次循环
          searchController.isEnd = true;
          searchController.page = 1;
          rule.currentPage = 1;
          CuratedFeedStorage.updateRulePage(rule.id, 1);
          break;
        }

        // 复用搜索模块四维过滤
        final filtered = searchController.getDataList(response);
        searchController.page++;
        rule.currentPage = searchController.page;
        CuratedFeedStorage.updateRulePage(rule.id, rule.currentPage);

        if (filtered != null && filtered.isNotEmpty) {
          buffer.addAll(filtered);
          if (buffer.length >= targetCount) {
            break;
          }
        } else {
          // 复用搜索控制器同款 100ms 拟人化呼吸防风控间隔
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } else {
        break;
      }
    }
  }
}

class CuratedFeedController extends GetxController
    with ScrollOrRefreshMixin {
  bool needRefresh = false;

  void markNeedRefresh() {
    needRefresh = true;
  }

  @override
  final ScrollController scrollController = ScrollController();

  final List<_KeywordWorker> _workers = [];
  final List<CuratedVideoItemModel> items = [];
  final Set<String> _globalSeenIds = {};

  int? lastRefreshAt;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final Rx<LoadingState<List<CuratedVideoItemModel>?>> loadingState =
      Rx<LoadingState<List<CuratedVideoItemModel>?>>(LoadingState.loading());

  @override
  void onInit() {
    super.onInit();
    _reloadWorkers();

    final cached = CuratedFeedStorage.getLastFeedItems();
    if (cached.isNotEmpty) {
      items.addAll(cached);
      for (final item in cached) {
        final key = (item.bvid != null && item.bvid!.isNotEmpty)
            ? item.bvid!
            : (item.aid != null && item.aid != 0)
                ? item.aid.toString()
                : '';
        if (key.isNotEmpty) _globalSeenIds.add(key);
      }
      loadingState.value = Success(List<CuratedVideoItemModel>.from(items));
    } else {
      onLoadMore();
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _reloadWorkers() {
    final rules =
        CuratedFeedStorage.getRules().where((r) => r.enabled).toList();
    _workers.clear();
    for (final rule in rules) {
      _workers.add(_KeywordWorker(rule: rule));
    }
  }

  Future<List<CuratedVideoItemModel>> _fetchBatch() async {
    if (_workers.isEmpty) return [];
    const int itemsPerRule = 3;
    final List<CuratedVideoItemModel> batch = [];

    for (final worker in _workers) {
      if (worker.buffer.length < itemsPerRule) {
        await worker.replenish(itemsPerRule);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      int count = 0;
      while (worker.buffer.isNotEmpty && count < itemsPerRule) {
        final item = worker.buffer.removeAt(0);
        final idKey = (item.bvid != null && item.bvid!.isNotEmpty)
            ? item.bvid!
            : (item.aid != null && item.aid != 0)
                ? item.aid.toString()
                : item.id?.toString() ?? '';

        if (idKey.isNotEmpty && _globalSeenIds.contains(idKey)) {
          continue;
        }
        if (idKey.isNotEmpty) {
          _globalSeenIds.add(idKey);
        }
        batch.add(CuratedVideoItemModel.fromSearchItem(
          item,
          worker.rule.keyword,
        ));
        count++;
      }
    }

    batch.shuffle(math.Random());
    return batch;
  }

  @override
  Future<void> onRefresh() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (_workers.isEmpty) {
        _reloadWorkers();
      }
      final newBatch = await _fetchBatch();
      if (newBatch.isNotEmpty) {
        items.insertAll(0, newBatch);
        lastRefreshAt = newBatch.length;
        if (items.length > 200) {
          items.removeRange(200, items.length);
        }
        CuratedFeedStorage.saveLastFeedItems(items);
        loadingState.value = Success(List<CuratedVideoItemModel>.from(items));
      } else if (items.isEmpty) {
        loadingState.value = const Success(<CuratedVideoItemModel>[]);
      }
    } catch (e) {
      if (items.isEmpty) {
        loadingState.value = Error(e.toString());
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> onLoadMore() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (_workers.isEmpty) {
        _reloadWorkers();
      }
      final newBatch = await _fetchBatch();
      if (newBatch.isNotEmpty) {
        items.addAll(newBatch);
        if (items.length > 200) {
          final removeCount = items.length - 200;
          items.removeRange(0, removeCount);
          if (lastRefreshAt != null) {
            lastRefreshAt = math.max(0, lastRefreshAt! - removeCount);
          }
        }
        CuratedFeedStorage.saveLastFeedItems(items);
        loadingState.value = Success(List<CuratedVideoItemModel>.from(items));
      } else if (items.isEmpty) {
        loadingState.value = const Success(<CuratedVideoItemModel>[]);
      }
    } catch (e) {
      if (items.isEmpty) {
        loadingState.value = Error(e.toString());
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> onReload() async {
    items.clear();
    _globalSeenIds.clear();
    lastRefreshAt = null;
    loadingState.value = LoadingState.loading();
    _reloadWorkers();
    for (final w in _workers) {
      w.reset();
    }
    await onLoadMore();
  }

  void removeItem(int index) {
    if (index >= 0 && index < items.length) {
      if (lastRefreshAt != null && index < lastRefreshAt!) {
        lastRefreshAt = lastRefreshAt! - 1;
      }
      items.removeAt(index);
      CuratedFeedStorage.saveLastFeedItems(items);
      loadingState.value = Success(List<CuratedVideoItemModel>.from(items));
    }
  }
}
