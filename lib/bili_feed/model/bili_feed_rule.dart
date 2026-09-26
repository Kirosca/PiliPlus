import 'package:PiliPlus/bili_feed/model/bili_feed_video_item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

class BiliFeedRule {
  final String id;
  String keyword;
  bool enabled;
  int order;
  int currentPage;

  BiliFeedRule({
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

  factory BiliFeedRule.fromJson(Map<String, dynamic> json) => BiliFeedRule(
        id: json['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        keyword: json['keyword'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        order: json['order'] as int? ?? 0,
        currentPage: json['currentPage'] as int? ?? 1,
      );
}

class BiliFeedStorage {
  static const List<String> defaultKeywords = [
    'TED演讲',
    '余华 #余华',
    '@影视飓风',
  ];

  static List<BiliFeedRule> getRules() {
    try {
      final raw = GStorage.setting.get(SettingBoxKey.curatedFeedRules);
      if (raw is List && raw.isNotEmpty) {
        final rules = raw.map((item) {
          if (item is Map) {
            return BiliFeedRule.fromJson(Map<String, dynamic>.from(item));
          } else if (item is String) {
            return BiliFeedRule(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              keyword: item,
            );
          }
          return BiliFeedRule(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            keyword: item.toString(),
          );
        }).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        const oldDefaults = ['Flutter -测试', '#以撒', '@嘤武罗'];
        const previousDefaults = ['TED演讲', '#余华', '@影视飓风'];
        final currentKeywords = rules.map((r) => r.keyword).toList();
        if (currentKeywords.length == 3 &&
            ((currentKeywords[0] == oldDefaults[0] &&
              currentKeywords[1] == oldDefaults[1] &&
              currentKeywords[2] == oldDefaults[2]) ||
             (currentKeywords[0] == previousDefaults[0] &&
              currentKeywords[1] == previousDefaults[1] &&
              currentKeywords[2] == previousDefaults[2]))) {
          return _generateDefaultRules();
        }

        return rules;
      }
    } catch (_) {}

    return _generateDefaultRules();
  }

  static List<BiliFeedRule> _generateDefaultRules() {
    final defaults = defaultKeywords.asMap().entries.map((entry) {
      return BiliFeedRule(
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

  static Future<void> saveRules(List<BiliFeedRule> rules) async {
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
      List<BiliFeedVideoItemModel> items) async {
    try {
      final saveList = items.take(100).map((e) => e.toJson()).toList();
      await GStorage.setting.put(SettingBoxKey.curatedFeedLastData, saveList);
    } catch (_) {}
  }

  static List<BiliFeedVideoItemModel> getLastFeedItems() {
    try {
      final raw = GStorage.setting.get(SettingBoxKey.curatedFeedLastData);
      if (raw is List && raw.isNotEmpty) {
        return raw
            .map((e) => BiliFeedVideoItemModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> clearLastFeedItems() async {
    try {
      await GStorage.setting.delete(SettingBoxKey.curatedFeedLastData);
    } catch (_) {}
  }
}

// 别名保证向后兼容
typedef CuratedFeedRule = BiliFeedRule;
typedef CuratedFeedStorage = BiliFeedStorage;
