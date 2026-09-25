import 'package:PiliPlus/bili_feed/core/chinese_converter.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// BiliFeed 统一过滤与关键词处理引擎
/// 负责搜索词脱壳提纯、繁简归一化、多条件布尔过滤、充电/课堂视频拦截以及视频实体去重
abstract final class BiliFilterEngine {
  /// 提取用于发送给 B 站 API 的搜索词
  /// 剥离 - 负向排除词，剥离 @ 与 # 前缀脱壳发送以获取最大候选池，统一转换为简体中文
  static String cleanKeyword(String keyword) {
    final rawList = keyword.trim().split(RegExp(r'\s+'));
    final searchTerms = <String>[];
    for (final k in rawList) {
      if (k.startsWith('-')) {
        continue; // 排除词不发给接口
      } else if (k.startsWith('@') || k.startsWith('#')) {
        if (k.length > 1) searchTerms.add(k.substring(1)); // 脱壳发送
      } else if (k.isNotEmpty) {
        searchTerms.add(k);
      }
    }
    final result = ChineseConverter.toSimplified(searchTerms.join(' '));
    return result.isEmpty ? ChineseConverter.toSimplified(keyword) : result;
  }

  /// 搜索视频列表的二级精确过滤
  /// 支持黑名单UP主过滤、排除词一票否决、多普通词 AND 匹配、#Tag过滤、@UP过滤、实体ID去重
  static List<SearchVideoItemModel> filterSearchVideos(
    List<SearchVideoItemModel> list, {
    required String keyword,
    bool titleMatchOnly = true,
    Set<String>? seenVideoIds,
  }) {
    final rawKeywords = ChineseConverter.toSimplified(keyword.trim().toLowerCase())
        .split(RegExp(r'\s+'));
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

    final filteredList = list.where((item) {
      // 0. 黑名单 UP 主一票否决
      final authorMid = item.owner?.mid;
      if (authorMid != null &&
          (GlobalData().blackMids.contains(authorMid) ||
              Pref.blackMids.contains(authorMid))) {
        return false;
      }

      final videoTitle =
          ChineseConverter.toSimplified((item.title ?? '').toLowerCase());
      final videoTags =
          ChineseConverter.toSimplified((item.tag ?? '').toLowerCase());
      final videoAuthor =
          ChineseConverter.toSimplified((item.owner?.name ?? '').toLowerCase());

      // 1. 负向排除词一票否决 (-)
      if (excludeKeywords.isNotEmpty &&
          excludeKeywords.any((k) => videoTitle.contains(k))) {
        return false;
      }

      // 2. 正向普通词全匹配 (AND)
      if (titleMatchOnly &&
          includeKeywords.isNotEmpty &&
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

      // 5. 实体去重
      if (seenVideoIds != null) {
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
          if (seenVideoIds.contains(idKey)) {
            return false;
          }
          seenVideoIds.add(idKey);
        }
      }

      return true;
    }).toList();

    return filteredList;
  }

  /// 充电专属视频识别（支持繁简归一化与各字段扫描）
  static bool isChargingVideo(SearchVideoItemModel item) {
    if (item.isCharging == true) return true;
    if (item.badge == '充电专属') return true;
    final title = ChineseConverter.toSimplified((item.title ?? '').toLowerCase());
    if (title.contains('充电专属') ||
        title.contains('充电专享') ||
        title.contains('包月充电')) {
      return true;
    }
    final tag = ChineseConverter.toSimplified((item.tag ?? '').toLowerCase());
    if (tag.contains('充电专属') || tag.contains('充电专享')) {
      return true;
    }
    final desc = ChineseConverter.toSimplified((item.desc ?? '').toLowerCase());
    if (desc.contains('充电专属') || desc.contains('包月充电观看')) {
      return true;
    }
    return false;
  }

  /// 课堂视频识别（支持各形态 cheese 课堂 URI 检测）
  static bool isClassroomVideo(dynamic item) {
    String? uri;
    if (item is SearchVideoItemModel) {
      if (item.badge == '课堂' || item.isPugv == true) {
        return true;
      }
      uri = item.arcurl;
    } else {
      try {
        uri = (item as dynamic).uri as String?;
      } catch (_) {}
    }
    final lowerUri = (uri ?? '').toLowerCase();
    if (lowerUri.contains('/cheese/') || lowerUri.contains('bilibili://cheese')) {
      return true;
    }
    return false;
  }
}
