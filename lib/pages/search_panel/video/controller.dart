import 'dart:math';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/common/search/video_search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class SearchVideoController
    extends SearchPanelController<SearchVideoData, SearchVideoItemModel> {
  SearchVideoController({
    required super.keyword,
    required super.searchType,
    required super.tag,
  });

  late bool hasJump2Video = false;

  final RxBool titleMatchOnly = true.obs;

  final Set<String> _seenVideoIds = <String>{};
  int _consecutiveEmptyCount = 0;
  int _autoFetchRetryCount = 0;

  @override
  void onInit() {
    super.onInit();
    videoDurationType = VideoDurationType.all;
    videoZoneType = VideoZoneType.all;
    DateTime now = DateTime.now();
    pubBeginDate = DateTime(now.year, now.month, 1, 0, 0, 0);
    pubEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    jump2Video();
  }

  @override
  Future<void> queryData([bool isRefresh = true]) async {
    if (isRefresh) {
      _autoFetchRetryCount = 0;
    }
    await super.queryData(isRefresh);

    if (!isRefresh &&
        loadingState.value is Error &&
        _consecutiveEmptyCount > 0 &&
        _autoFetchRetryCount < 1) {
      _autoFetchRetryCount++;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isLoading && !isEnd) {
          queryData(false);
        }
      });
    }
  }

  // 提取用于发送给 B 站 API 的纯正向搜索词
  String get cleanSearchKeyword {
    final rawList = keyword.trim().split(RegExp(r'\s+'));
    final positiveWords =
        rawList.where((k) => !k.startsWith('-') || k.length <= 1);
    final result = positiveWords.join(' ');
    return result.isEmpty ? keyword : result;
  }

  @override
  Future<LoadingState<SearchVideoData>> customGetData() =>
      SearchHttp.searchByType<SearchVideoData>(
        searchType: searchType,
        keyword: cleanSearchKeyword,
        page: page,
        order: order,
        duration: videoDurationType?.index,
        tids: videoZoneType?.tids,
        pubBegin: pubBegin,
        pubEnd: pubEnd,
        gaiaVtoken: gaiaVtoken,
        onSuccess: (String gaiaVtoken) {
          this.gaiaVtoken = gaiaVtoken;
          queryData(page == 1);
        },
      );

  @override
  List<SearchVideoItemModel>? getDataList(SearchVideoData response) {
    final list = response.list;
    if (list == null || list.isEmpty) return list;

    if (page == 1) {
      _seenVideoIds.clear();
      _consecutiveEmptyCount = 0;
    }

    final rawKeywords =
        keyword.trim().toLowerCase().split(RegExp(r'\s+'));
    final includeKeywords = <String>[];
    final excludeKeywords = <String>[];

    for (final k in rawKeywords) {
      if (k.startsWith('-') && k.length > 1) {
        excludeKeywords.add(k.substring(1));
      } else if (k.isNotEmpty) {
        includeKeywords.add(k);
      }
    }

    final filteredList = list.where((item) {
      if (titleMatchOnly.value) {
        final videoTitle = (item.title ?? '').toLowerCase();

        // 1. 正向多词全匹配：必须包含所有的必含词
        if (includeKeywords.isNotEmpty &&
            !includeKeywords.every((k) => videoTitle.contains(k))) {
          return false;
        }

        // 2. 负向排除词过滤：包含任意一个排除词则强行剔除
        if (excludeKeywords.isNotEmpty &&
            excludeKeywords.any((k) => videoTitle.contains(k))) {
          return false;
        }
      }

      final idKey = (item.bvid != null && item.bvid!.isNotEmpty)
          ? item.bvid
          : (item.aid != null && item.aid != 0)
              ? item.aid.toString()
              : (item.seasonId != null && item.seasonId != 0)
                  ? 'season_${item.seasonId}'
                  : (item.roomId != null && item.roomId != 0)
                      ? 'room_${item.roomId}'
                      : (item.id != null && item.id != 0)
                          ? item.id.toString()
                          : null;

      if (idKey != null && idKey.isNotEmpty) {
        if (_seenVideoIds.contains(idKey)) {
          return false;
        }
        _seenVideoIds.add(idKey);
      }

      return true;
    }).toList();

    if (filteredList.isNotEmpty) {
      _consecutiveEmptyCount = 0;
    } else if (list.isNotEmpty && !isEnd) {
      _consecutiveEmptyCount++;
      if (_consecutiveEmptyCount < 15) {
        Future.microtask(() {
          if (!isLoading && !isEnd) {
            queryData(false);
          }
        });
      }
    }

    return filteredList;
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<SearchVideoData> response) {
    searchResultController?.count[searchType.index] =
        response.response.numResults ?? 0;
    if (searchType == SearchType.video && !hasJump2Video && isRefresh) {
      hasJump2Video = true;
      onPushDetail(response.response.list);
    }
    return false;
  }

  void onPushDetail(List<SearchVideoItemModel>? resultList) {
    try {
      int? aid = int.tryParse(keyword);
      if (aid != null && resultList?.firstOrNull?.aid == aid) {
        PiliScheme.videoPush(aid, null, showDialog: false);
      }
    } catch (_) {}
  }

  void jump2Video() {
    if (IdUtils.avRegexExact.hasMatch(keyword)) {
      hasJump2Video = true;
      PiliScheme.videoPush(
        int.parse(keyword.substring(2)),
        null,
        showDialog: false,
      );
    } else if (IdUtils.bvRegexExact.hasMatch(keyword)) {
      hasJump2Video = true;
      PiliScheme.videoPush(null, keyword, showDialog: false);
    }
  }

  final Rx<ArchiveFilterType> selectedType = ArchiveFilterType.totalrank.obs;
  VideoPubTimeType? pubTimeType = VideoPubTimeType.all;
  late DateTime pubBeginDate;
  late DateTime pubEndDate;
  bool customPubBeginDate = false;
  bool customPubEndDate = false;

  void onShowFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          Widget dateWidget([bool isFirst = true]) {
            final enable =
                pubTimeType == null &&
                (isFirst ? customPubBeginDate : customPubEndDate);
            return SearchText(
              text: DateFormatUtils.longFormat.format(
                isFirst ? pubBeginDate : pubEndDate,
              ),
              textAlign: TextAlign.center,
              onTap: (text) {
                showDatePicker(
                  context: context,
                  initialDate: isFirst ? pubBeginDate : pubEndDate,
                  firstDate: isFirst ? DateTime(2009, 6, 26) : pubBeginDate,
                  lastDate: isFirst ? pubEndDate : DateTime.now(),
                ).then((selectedDate) {
                  if (selectedDate != null) {
                    if (isFirst) {
                      customPubBeginDate = true;
                      pubBeginDate = selectedDate;
                    } else {
                      customPubEndDate = true;
                      pubEndDate = selectedDate;
                    }
                    pubTimeType = null;
                    SmartDialog.dismiss();
                    pubBegin =
                        DateTime(
                          pubBeginDate.year,
                          pubBeginDate.month,
                          pubBeginDate.day,
                          0,
                          0,
                          0,
                        ).millisecondsSinceEpoch ~/
                        1000;
                    pubEnd =
                        DateTime(
                          pubEndDate.year,
                          pubEndDate.month,
                          pubEndDate.day,
                          23,
                          59,
                          59,
                        ).millisecondsSinceEpoch ~/
                        1000;
                    setState(() {});
                    onSortSearch(getBack: false);
                  }
                });
              },
              bgColor: enable
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.outline.withValues(alpha: 0.1),
              textColor: enable
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.outline.withValues(alpha: 0.8),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 20,
              left: 16,
              right: 16,
              bottom: 100 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('仅匹配标题关键词', style: TextStyle(fontSize: 16)),
                    Obx(
                      () => Switch(
                        value: titleMatchOnly.value,
                        onChanged: (val) {
                          titleMatchOnly.value = val;
                          onSortSearch(getBack: false);
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),
                const Text('发布时间', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: VideoPubTimeType.values.map(
                    (e) {
                      final isCurr = e == pubTimeType;
                      return SearchText(
                        text: e.label,
                        onTap: (text) {
                          pubTimeType = e;
                          DateTime now = DateTime.now();
                          if (e == VideoPubTimeType.all) {
                            pubBegin = null;
                            pubEnd = null;
                          } else {
                            pubBegin =
                                DateTime(
                                  now.year,
                                  now.month,
                                  now.day -
                                      (e == VideoPubTimeType.day
                                          ? 0
                                          : e == VideoPubTimeType.week
                                          ? 6
                                          : 179),
                                  0,
                                  0,
                                  0,
                                ).millisecondsSinceEpoch ~/
                                1000;
                            pubEnd =
                                DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  23,
                                  59,
                                  59,
                                ).millisecondsSinceEpoch ~/
                                1000;
                          }
                          onSortSearch();
                        },
                        bgColor: isCurr
                            ? theme.colorScheme.secondaryContainer
                            : null,
                        textColor: isCurr
                            ? theme.colorScheme.onSecondaryContainer
                            : null,
                      );
                    },
                  ).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(child: dateWidget()),
                    const Text('至', style: TextStyle(fontSize: 13)),
                    Expanded(child: dateWidget(false)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('内容时长', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: VideoDurationType.values.map(
                    (e) {
                      final isCurr = e == videoDurationType;
                      return SearchText(
                        text: e.label,
                        onTap: (_) {
                          videoDurationType = e;
                          onSortSearch(label: e.label);
                        },
                        bgColor: isCurr
                            ? theme.colorScheme.secondaryContainer
                            : null,
                        textColor: isCurr
                            ? theme.colorScheme.onSecondaryContainer
                            : null,
                      );
                    },
                  ).toList(),
                ),
                const SizedBox(height: 20),
                const Text('内容分区', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: VideoZoneType.values.map(
                    (e) {
                      final isCurr = e == videoZoneType;
                      return SearchText(
                        text: e.label,
                        onTap: (_) {
                          videoZoneType = e;
                          onSortSearch(label: e.label);
                        },
                        bgColor: isCurr
                            ? theme.colorScheme.secondaryContainer
                            : null,
                        textColor: isCurr
                            ? theme.colorScheme.onSecondaryContainer
                            : null,
                      );
                    },
                  ).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
