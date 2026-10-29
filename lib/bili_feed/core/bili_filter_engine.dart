import 'package:PiliPlus/bili_feed/core/chinese_converter.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

enum FilterTarget { title, tag, author }

class FilterToken {
  final bool isNeg;
  final FilterTarget target;
  final bool isExact;
  final String val;

  const FilterToken({
    required this.isNeg,
    required this.target,
    required this.isExact,
    required this.val,
  });

  @override
  String toString() =>
      'FilterToken(isNeg: $isNeg, target: $target, isExact: $isExact, val: $val)';
}

class SearchFilterQuery {
  final List<FilterToken> exclusions;
  final List<List<FilterToken>> branches;
  final bool hasRules;

  const SearchFilterQuery({
    required this.exclusions,
    required this.branches,
    required this.hasRules,
  });
}

/// BiliFeed 统一过滤与关键词处理引擎（2.2 高级布尔逻辑架构：三维排除、| 分支、引号精确匹配）
abstract final class BiliFilterEngine {
  /// 通用文本清洗：繁简归一化、HTML实体反转义与全角标点标准化
  static String cleanText(String str) {
    if (str.isEmpty) return '';
    final simplified = ChineseConverter.toSimplified(str);
    return simplified
        .replaceAll(RegExp(r"&#x27;|&#39;|&apos;"), "'")
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r"[\u2018\u2019\u201A\u201B\uFF07`]"), "'")
        .replaceAll(RegExp(r'[\u201C\u201D\uFF02]'), '"')
        .replaceAll('\uFF5C', '|')
        .replaceAll('\uFF03', '#')
        .replaceAll('\uFF20', '@')
        .replaceAll('\uFF0D', '-')
        .trim()
        .toLowerCase();
  }

  /// 顶层按 | 切分分支
  static List<String> splitByTopLevelPipe(String str) {
    final branches = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      if (char == '|') {
        final segment = buffer.toString().trim();
        if (segment.isNotEmpty) branches.add(segment);
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    final rest = buffer.toString().trim();
    if (rest.isNotEmpty) branches.add(rest);
    return branches;
  }

  /// 带引号容错的分支词法切词
  static List<String> tokenizeBranch(String branchStr) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;
    String quoteChar = '';

    for (int i = 0; i < branchStr.length; i++) {
      final char = branchStr[i];
      if (inQuote) {
        // 引号容错：若未闭合且遇空白后紧跟新操作符（@、#、-），自动截断当前未闭合 token
        if (RegExp(r'\s').hasMatch(char)) {
          final rest = branchStr.substring(i).trim();
          if (RegExp(r'^[-#@]').hasMatch(rest)) {
            if (buffer.isNotEmpty) {
              tokens.add(buffer.toString());
              buffer.clear();
            }
            inQuote = false;
            quoteChar = '';
            continue;
          }
        }
        buffer.write(char);
        if (char == quoteChar) inQuote = false;
      } else {
        if (char == '"' || char == "'") {
          inQuote = true;
          quoteChar = char;
          buffer.write(char);
        } else if (RegExp(r'\s').hasMatch(char)) {
          if (buffer.isNotEmpty) {
            tokens.add(buffer.toString());
            buffer.clear();
          }
        } else {
          buffer.write(char);
        }
      }
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  /// 单个 Token 解析：识别负向排除（-）、作用目标（#Tag / @UP / 标题）与引号精确度
  static FilterToken? parseToken(String rawToken) {
    String t = rawToken.trim();
    if (t.isEmpty) return null;

    bool isNeg = false;
    if (t.startsWith('-')) {
      isNeg = true;
      t = t.substring(1);
    }

    FilterTarget target = FilterTarget.title;
    if (t.startsWith('#')) {
      target = FilterTarget.tag;
      t = t.substring(1);
    } else if (t.startsWith('@')) {
      target = FilterTarget.author;
      t = t.substring(1);
    }

    bool isExact = false;
    String val = t;
    if (val.startsWith('"') ||
        val.startsWith("'") ||
        val.endsWith('"') ||
        val.endsWith("'")) {
      isExact = true;
      val = val.replaceAll(RegExp(r"""^["']+|["']+$"""), '');
    }

    final cleanVal = cleanText(val);
    if (cleanVal.isEmpty) return null;

    return FilterToken(
      isNeg: isNeg,
      target: target,
      isExact: isExact,
      val: cleanVal,
    );
  }

  /// 结构化解析检索式为布尔查询对象
  static SearchFilterQuery parseSearchQuery(String keyword) {
    final cleaned = cleanText(keyword);
    if (cleaned.isEmpty) {
      return const SearchFilterQuery(
        exclusions: [],
        branches: [],
        hasRules: false,
      );
    }

    final branchStrings = splitByTopLevelPipe(cleaned);
    final exclusions = <FilterToken>[];
    final branches = <List<FilterToken>>[];

    for (final bStr in branchStrings) {
      final rawTokens = tokenizeBranch(bStr);
      final posTokens = <FilterToken>[];

      for (final rt in rawTokens) {
        final parsed = parseToken(rt);
        if (parsed == null) continue;
        if (parsed.isNeg) {
          exclusions.add(parsed);
        } else {
          posTokens.add(parsed);
        }
      }
      if (posTokens.isNotEmpty) {
        branches.add(posTokens);
      }
    }

    return SearchFilterQuery(
      exclusions: exclusions,
      branches: branches,
      hasRules: exclusions.isNotEmpty || branches.isNotEmpty,
    );
  }

  /// 提取用于发送给 B 站 API 的搜索词（智能脱壳与负向规则剥离）
  static String cleanKeyword(String keyword) {
    if (keyword.trim().isEmpty) return '';
    final query = parseSearchQuery(keyword);
    if (!query.hasRules) {
      return ChineseConverter.toSimplified(keyword.trim());
    }

    final positiveTerms = <String>[];
    for (final branch in query.branches) {
      for (final cond in branch) {
        if (cond.val.isNotEmpty) {
          positiveTerms.add(cond.val);
        }
      }
    }

    // 剔除重复词，保持检索请求精简
    final uniqueTerms = positiveTerms.toSet().toList();
    final result = uniqueTerms.join(' ');
    return result.isEmpty
        ? ChineseConverter.toSimplified(
            keyword.replaceAll(RegExp(r'[-#@|]'), ' ').trim())
        : result;
  }

  /// 搜索视频列表的二级精确过滤（2.2 布尔引擎：NOT 优先 -> OR 分支 -> AND 分支内全匹配）
  static List<SearchVideoItemModel> filterSearchVideos(
    List<SearchVideoItemModel> list, {
    required String keyword,
    bool titleMatchOnly = true,
    Set<String>? seenVideoIds,
  }) {
    final query = parseSearchQuery(keyword);

    final filteredList = list.where((item) {
      // 0. 黑名单 UP 主一票否决
      final authorMid = item.owner?.mid;
      if (authorMid != null &&
          (GlobalData().blackMids.contains(authorMid) ||
              Pref.blackMids.contains(authorMid))) {
        return false;
      }

      // 规则存在时执行安检过滤
      if (query.hasRules) {
        final videoTitle = cleanText(item.title ?? '');
        final videoAuthor = cleanText(item.owner?.name ?? '');
        final rawTags = cleanText(item.tag ?? '');
        final tagList = rawTags
            .split(RegExp(r'[,，、\s]+'))
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        final tagSet = tagList.toSet();

        // 1. 全局排除检查（NOT）：只要命中任一排除条件（标题/UP/Tag），一票否决
        for (final ex in query.exclusions) {
          switch (ex.target) {
            case FilterTarget.title:
              if (videoTitle.contains(ex.val)) return false;
            case FilterTarget.author:
              if (ex.isExact
                  ? (videoAuthor == ex.val)
                  : videoAuthor.contains(ex.val)) {
                return false;
              }
            case FilterTarget.tag:
              if (ex.isExact
                  ? tagSet.contains(ex.val)
                  : (tagList.any((t) => t.contains(ex.val)) ||
                      rawTags.contains(ex.val))) {
                return false;
              }
          }
        }

        // 2. 如果只有排除条件没有正向分支条件，排除通过即保留
        if (query.branches.isNotEmpty) {
          // 3. 多分支判定（OR）：满足任意一个分支即可放行
          final anyBranchMatch = query.branches.any((branch) {
            // (1) 标题条件全满足 (AND)
            if (titleMatchOnly) {
              final titleConds =
                  branch.where((c) => c.target == FilterTarget.title);
              final titleMatch = titleConds
                  .every((c) => videoTitle.contains(c.val));
              if (!titleMatch) return false;
            }

            // (2) 标签条件全满足 (AND)
            final tagConds =
                branch.where((c) => c.target == FilterTarget.tag);
            final tagMatch = tagConds.every((c) => c.isExact
                ? tagSet.contains(c.val)
                : (tagList.any((t) => t.contains(c.val)) ||
                    rawTags.contains(c.val)));
            if (!tagMatch) return false;

            // (3) 作者条件宽松匹配 (OR)：同一分支内满足任一指定 UP 主即可
            final authorConds =
                branch.where((c) => c.target == FilterTarget.author);
            final authorMatch = authorConds.isEmpty ||
                authorConds.any((c) => c.isExact
                    ? videoAuthor == c.val
                    : videoAuthor.contains(c.val));
            return authorMatch;
          });

          if (!anyBranchMatch) return false;
        }
      }

      // 4. 实体去重
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
          // 容量保护：超过 1500 条时淘汰最早记录的 300 条，防止长时间挂起内存膨胀
          if (seenVideoIds.length >= 1500) {
            seenVideoIds.removeAll(seenVideoIds.take(300).toList());
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
