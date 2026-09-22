import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/curated/curated_feed_rule.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class _KeywordWorker {
  final CuratedFeedRule rule;
  int page = 1;
  bool isEnd = false;
  final List<SearchVideoItemModel> buffer = [];
  final Set<String> seenIds = {};

  _KeywordWorker({required this.rule});

  void reset() {
    page = 1;
    isEnd = false;
    buffer.clear();
    seenIds.clear();
  }

  String get cleanSearchKeyword {
    final rawList = rule.keyword.trim().split(RegExp(r'\s+'));
    final searchTerms = <String>[];
    for (final k in rawList) {
      if (k.startsWith('-')) {
        continue;
      } else if (k.startsWith('@') || k.startsWith('#')) {
        if (k.length > 1) searchTerms.add(k.substring(1));
      } else if (k.isNotEmpty) {
        searchTerms.add(k);
      }
    }
    final result = searchTerms.join(' ');
    return result.isEmpty ? rule.keyword : result;
  }

  List<SearchVideoItemModel> applyFilter(List<SearchVideoItemModel> list) {
    final rawKeywords =
        rule.keyword.trim().toLowerCase().split(RegExp(r'\s+'));
    final includeKeywords = <String>[];
    final excludeKeywords = <String>[];
    final tagKeywords = <String>[];
    final upKeywords = <String>[];

    for (final k in rawKeywords) {
      if (k.startsWith('-') && k.length > 1) {
        excludeKeywords.add(k.substring(1));
      } else if (k.startsWith('#') && k.length > 1) {
        tagKeywords.add(k.substring(1));
      } else if (k.startsWith('@') && k.length > 1) {
        upKeywords.add(k.substring(1));
      } else if (k.isNotEmpty) {
        includeKeywords.add(k);
      }
    }

    final filtered = list.where((item) {
      final videoTitle = (item.title ?? '').toLowerCase();
      final videoTags = (item.tag ?? '').toLowerCase();
      final videoAuthor = (item.owner?.name ?? '').toLowerCase();

      // 1. 负向排除词一票否决 (-)
      if (excludeKeywords.isNotEmpty &&
          excludeKeywords.any((k) => videoTitle.contains(k))) {
        return false;
      }

      // 2. 正向普通词全匹配 (AND)
      if (includeKeywords.isNotEmpty &&
          !includeKeywords.every((k) => videoTitle.contains(k))) {
        return false;
      }

      // 3. Tag 标签过滤 (#)
      if (tagKeywords.isNotEmpty &&
          !tagKeywords.every((k) => videoTags.contains(k))) {
        return false;
      }

      // 4. UP 主作者过滤 (@)
      if (upKeywords.isNotEmpty &&
          !upKeywords.any((k) => videoAuthor.contains(k))) {
        return false;
      }

      final idKey = (item.bvid != null && item.bvid!.isNotEmpty)
          ? item.bvid!
          : (item.aid != null && item.aid != 0)
              ? item.aid.toString()
              : (item.id != null && item.id != 0)
                  ? item.id.toString()
                  : null;

      if (idKey != null && idKey.isNotEmpty) {
        if (seenIds.contains(idKey)) return false;
        seenIds.add(idKey);
      }

      return true;
    }).toList();

    return filtered;
  }

  Future<void> replenish(int targetCount) async {
    int attempts = 0;
    while (buffer.length < targetCount && attempts < 3) {
      if (attempts > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      attempts++;
      final res = await SearchHttp.searchByType<SearchVideoData>(
        searchType: SearchType.video,
        keyword: cleanSearchKeyword,
        page: page,
        gaiaVtoken: CuratedFeedController.gaiaVtoken,
        onSuccess: (token) {
          CuratedFeedController.gaiaVtoken = token;
        },
      );

      if (res case Success(:final response)) {
        final list = response.list;
        if (list == null || list.isEmpty) {
          // 该关键词见底，自动从第 1 页循环从头来
          page = 1;
          seenIds.clear();
          isEnd = true;
          break;
        }

        final filtered = applyFilter(list);
        buffer.addAll(filtered);
        page++;

        if (buffer.length >= targetCount) {
          break;
        }
      } else {
        // 遭遇风控/网络异常，停止该 worker 的额外连续重试，防止反复弹窗
        break;
      }
    }
  }
}

class CuratedFeedController extends GetxController
    with ScrollOrRefreshMixin {
  static String? gaiaVtoken;
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
    final rules = CuratedFeedStorage.getRules().where((r) => r.enabled).toList();
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
          // 拟人化呼吸防频控 (250ms)
          await Future.delayed(const Duration(milliseconds: 250));
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
