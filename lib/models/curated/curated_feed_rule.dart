import 'package:PiliPlus/models/curated/curated_video_item_model.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

class CuratedFeedRule {
  final String id;
  String keyword;
  bool enabled;
  int order;
  int currentPage;

  CuratedFeedRule({
    required this.id,
    required this.keyword,
    this.enabled = true,
    this.order = 0,
    this.currentPage = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyword': keyword,
        'enabled': enabled,
        'order': order,
        'currentPage': currentPage,
      };

  factory CuratedFeedRule.fromJson(Map<String, dynamic> json) =>
      CuratedFeedRule(
        id: json['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        keyword: json['keyword'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        order: json['order'] as int? ?? 0,
        currentPage: json['currentPage'] as int? ?? 1,
      );
}

class CuratedFeedStorage {
  static const List<String> defaultKeywords = [
    'TED演讲',
    '#余华',
    '@影视飓风',
  ];

  static List<CuratedFeedRule> getRules() {
    try {
      final raw = GStorage.setting.get(SettingBoxKey.curatedFeedRules);
      if (raw is List && raw.isNotEmpty) {
        final rules = raw.map((item) {
          if (item is Map) {
            return CuratedFeedRule.fromJson(Map<String, dynamic>.from(item));
          } else if (item is String) {
            return CuratedFeedRule(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              keyword: item,
            );
          }
          return CuratedFeedRule(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            keyword: item.toString(),
          );
        }).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        const oldDefaults = ['Flutter -测试', '#以撒', '@嘤武罗'];
        final currentKeywords = rules.map((r) => r.keyword).toList();
        if (currentKeywords.length == 3 &&
            currentKeywords[0] == oldDefaults[0] &&
            currentKeywords[1] == oldDefaults[1] &&
            currentKeywords[2] == oldDefaults[2]) {
          return _generateDefaultRules();
        }

        return rules;
      }
    } catch (_) {}

    return _generateDefaultRules();
  }

  static List<CuratedFeedRule> _generateDefaultRules() {
    final defaults = defaultKeywords.asMap().entries.map((entry) {
      return CuratedFeedRule(
        id: 'default_${entry.key}',
        keyword: entry.value,
        enabled: true,
        order: entry.key,
        currentPage: 1,
      );
    }).toList();
    saveRules(defaults);
    return defaults;
  }

  static Future<void> saveRules(List<CuratedFeedRule> rules) async {
    final list = rules.map((r) => r.toJson()).toList();
    await GStorage.setting.put(SettingBoxKey.curatedFeedRules, list);
  }

  static Future<void> updateRulePage(String ruleId, int page) async {
    final rules = getRules();
    bool found = false;
    for (final rule in rules) {
      if (rule.id == ruleId) {
        rule.currentPage = page;
        found = true;
        break;
      }
    }
    if (found) {
      await saveRules(rules);
    }
  }

  static Future<void> saveLastFeedItems(
      List<CuratedVideoItemModel> items) async {
    try {
      final saveList = items.take(100).map((e) => e.toJson()).toList();
      await GStorage.setting.put(SettingBoxKey.curatedFeedLastData, saveList);
    } catch (_) {}
  }

  static List<CuratedVideoItemModel> getLastFeedItems() {
    try {
      final raw = GStorage.setting.get(SettingBoxKey.curatedFeedLastData);
      if (raw is List && raw.isNotEmpty) {
        return raw
            .map((e) => CuratedVideoItemModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> clearLastFeedItems() async {
    try {
      await GStorage.setting.remove(SettingBoxKey.curatedFeedLastData);
    } catch (_) {}
  }
}
