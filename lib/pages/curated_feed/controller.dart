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

  static bool isClassroomVideo(SearchVideoItemModel item) {
    if (item.isPugv == true) return true;
    if (item.badge == '课堂') return true;
    final url = (item.arcurl ?? '').toLowerCase();
    if (url.contains('/cheese/') || url.contains('bilibili://cheese')) {
      return true;
    }
    return false;
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
          // 选推专属额外筛选层：剔除课堂视频（PUGV / 芝士课堂）
          final validList =
              filtered.where((item) => !isClassroomVideo(item)).toList();
          if (validList.isNotEmpty) {
            buffer.addAll(validList);
            if (buffer.length >= targetCount) {
              break;
            }
          } else {
            await Future.delayed(const Duration(milliseconds: 100));
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
  bool needReload = false;
  bool get needRefresh => needReload;
  set needRefresh(bool v) => needReload = v;

  void markNeedRefresh() => markNeedReload();
  void markNeedReload() {
    needReload = true;
  }

  void onRulesChanged() {
    needReload = false;
    onReload();
  }

  @override
  final ScrollController scrollController = ScrollController();

  final List<_KeywordWorker> _workers = [];
  final List<CuratedVideoItemModel> items = [];
  final Set<String> _globalSeenIds = {};
  String _rulesFingerprint = '';

  int? lastRefreshAt;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final Rx<LoadingState<List<CuratedVideoItemModel>?>> loadingState =
      Rx<LoadingState<List<CuratedVideoItemModel>?>>(LoadingState.loading());

  String _calcRulesFingerprint(List<CuratedFeedRule> rules) {
    return rules
        .map((r) => '${r.id}:${r.keyword}:${r.enabled}:${r.order}')
        .join(';');
  }

  @override
  void onInit() {
    super.onInit();
    _reloadWorkers();

    final cached = CuratedFeedStorage.getLastFeedItems();
    if (cached.isNotEmpty) {
      final validCached = cached.where((item) {
        final uri = (item.uri ?? '').toLowerCase();
        return !uri.contains('/cheese/') && !uri.contains('bilibili://cheese');
      }).toList();
      items.addAll(validCached);
      for (final item in validCached) {
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
    _rulesFingerprint = _calcRulesFingerprint(rules);
    _workers.clear();
    for (final rule in rules) {
      _workers.add(_KeywordWorker(rule: rule));
    }
  }

  String _getIdKey(SearchVideoItemModel item) {
    return (item.bvid != null && item.bvid!.isNotEmpty)
        ? item.bvid!
        : (item.aid != null && item.aid != 0)
            ? item.aid.toString()
            : item.id?.toString() ?? '';
  }

  Future<List<CuratedVideoItemModel>> _fetchBatch() async {
    final currentRules =
        CuratedFeedStorage.getRules().where((r) => r.enabled).toList();
    final newFingerprint = _calcRulesFingerprint(currentRules);
    if (newFingerprint != _rulesFingerprint) {
      _reloadWorkers();
    }

    if (_workers.isEmpty) return [];

    const int maxTotal = 21;
    final int n = _workers.length;
    final int baseQuota = maxTotal ~/ n;
    final int minTargetPerWorker = math.max(1, baseQuota);

    // 1. 各 Worker 先按启用规则平均分配：检查缓冲区并向 API 补仓
    for (final worker in _workers) {
      if (worker.buffer.length < minTargetPerWorker) {
        await worker.replenish(minTargetPerWorker);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    final List<CuratedVideoItemModel> batch = [];

    // 从每个 worker 中先提取最多 baseQuota 个（排重后）
    if (baseQuota > 0) {
      for (final worker in _workers) {
        int count = 0;
        while (worker.buffer.isNotEmpty && count < baseQuota) {
          final item = worker.buffer.removeAt(0);
          final idKey = _getIdKey(item);

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
    }

    // 2. 如果除不断（或某些规则出货不足有空位），余数按过滤后视频存量（worker.buffer.length）最大的顺位填充
    // （不新搜索视频而是存量中填充，如果最大顺位填充不满则后位填充，以此类推）
    int remainingSlots = maxTotal - batch.length;
    if (remainingSlots > 0) {
      final sortedWorkers = List<_KeywordWorker>.from(_workers)
        ..sort((a, b) => b.buffer.length.compareTo(a.buffer.length));

      for (final worker in sortedWorkers) {
        if (remainingSlots <= 0) break;
        while (worker.buffer.isNotEmpty && remainingSlots > 0) {
          final item = worker.buffer.removeAt(0);
          final idKey = _getIdKey(item);

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
          remainingSlots--;
        }
      }
    }

    // 3. 随机打散交织
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
