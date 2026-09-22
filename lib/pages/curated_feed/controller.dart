import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/curated/curated_feed_rule.dart';
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
  }

  void reset() {
    searchController.page = 1;
    searchController.isEnd = false;
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
      }

      final res = await searchController.customGetData();
      if (res case Success(:final response)) {
        final rawList = response.list;
        if (rawList == null || rawList.isEmpty) {
          // B 站当前轮到底，标记并在下次循环
          searchController.isEnd = true;
          break;
        }

        // 复用搜索模块四维过滤
        final filtered = searchController.getDataList(response);
        searchController.page++;

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
  final List<SearchVideoItemModel> items = [];
  final Set<String> _globalSeenIds = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final Rx<LoadingState<List<SearchVideoItemModel>?>> loadingState =
      Rx<LoadingState<List<SearchVideoItemModel>?>>(LoadingState.loading());

  @override
  void onInit() {
    super.onInit();
    queryData(true);
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

  @override
  Future<void> onRefresh() async {
    await queryData(true);
  }

  Future<void> onLoadMore() async {
    if (_isLoading) return;
    await queryData(false);
  }

  Future<void> queryData([bool isRefresh = false]) async {
    if (_isLoading) return;
    _isLoading = true;

    if (isRefresh) {
      loadingState.value = LoadingState.loading();
      items.clear();
      _globalSeenIds.clear();
      _reloadWorkers();
      for (final w in _workers) {
        w.reset();
      }
    }

    if (_workers.isEmpty) {
      _isLoading = false;
      loadingState.value = const Success(<SearchVideoItemModel>[]);
      return;
    }

    try {
      // 每次按平分比例从每个 worker 中提取 itemsPerRule 个视频
      const int itemsPerRule = 3;
      final List<SearchVideoItemModel> batch = [];

      for (final worker in _workers) {
        if (worker.buffer.length < itemsPerRule) {
          await worker.replenish(itemsPerRule);
          // 复用搜索模块 100ms 拟人化呼吸防频控
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
          batch.add(item);
          count++;
        }
      }

      // 将本批次平分收集到的视频进行混排打乱
      batch.shuffle(math.Random());
      items.addAll(batch);

      loadingState.value = Success(List<SearchVideoItemModel>.from(items));
    } catch (e) {
      if (items.isEmpty) {
        loadingState.value = Error(e.toString());
      }
    } finally {
      _isLoading = false;
    }
  }
}
