import 'package:PiliPlus/bili_feed/core/bili_filter_engine.dart';
import 'package:PiliPlus/bili_feed/core/chinese_converter.dart';
import 'package:PiliPlus/models/search/result.dart';

export 'package:PiliPlus/bili_feed/core/bili_filter_engine.dart';
export 'package:PiliPlus/bili_feed/core/chinese_converter.dart';
export 'package:PiliPlus/bili_feed/model/bili_feed_rule.dart';
export 'package:PiliPlus/bili_feed/model/bili_feed_video_item.dart';
export 'package:PiliPlus/bili_feed/page/bili_feed_controller.dart';
export 'package:PiliPlus/bili_feed/page/bili_feed_setting_view.dart';
export 'package:PiliPlus/bili_feed/page/bili_feed_view.dart';

/// BiliFeedHook 是专门向上游暴露的极简静态门面类（Facade）
/// 使得上游代码（如 SearchVideoController）只需一行 Hook 调用，实现与定制逻辑的完全解耦
abstract final class BiliFeedHook {
  /// 搜索词发送前清洗：脱壳、去排除词、出站简繁归一化
  static String cleanKeyword(String keyword) =>
      BiliFilterEngine.cleanKeyword(keyword);

  /// 搜索列表结果四维过滤：AND 匹配、- 排除、#Tag、@UP 主、实体去重
  static List<SearchVideoItemModel> applyFilter(
    List<SearchVideoItemModel> list, {
    required String keyword,
    bool titleMatchOnly = true,
    Set<String>? seenVideoIds,
  }) =>
      BiliFilterEngine.filterSearchVideos(
        list,
        keyword: keyword,
        titleMatchOnly: titleMatchOnly,
        seenVideoIds: seenVideoIds,
      );

  /// 充电专属视频识别
  static bool isChargingVideo(SearchVideoItemModel item) =>
      BiliFilterEngine.isChargingVideo(item);

  /// 课堂视频识别
  static bool isClassroomVideo(dynamic item) =>
      BiliFilterEngine.isClassroomVideo(item);

  /// 字符串转简体中文
  static String toSimplified(String text) =>
      ChineseConverter.toSimplified(text);
}
