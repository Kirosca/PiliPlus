import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

class CuratedFeedRule {
  final String id;
  String keyword;
  bool enabled;
  int order;

  CuratedFeedRule({
    required this.id,
    required this.keyword,
    this.enabled = true,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyword': keyword,
        'enabled': enabled,
        'order': order,
      };

  factory CuratedFeedRule.fromJson(Map<String, dynamic> json) =>
      CuratedFeedRule(
        id: json['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        keyword: json['keyword'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        order: json['order'] as int? ?? 0,
      );
}

class CuratedFeedStorage {
  static const List<String> defaultKeywords = [
    'Flutter -测试',
    '#以撒',
    '@嘤武罗',
  ];

  static List<CuratedFeedRule> getRules() {
    try {
      final raw = GStorage.setting.get(SettingBoxKey.curatedFeedRules);
      if (raw is List && raw.isNotEmpty) {
        return raw.map((item) {
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
      }
    } catch (_) {}

    final defaults = defaultKeywords.asMap().entries.map((entry) {
      return CuratedFeedRule(
        id: 'default_${entry.key}',
        keyword: entry.value,
        enabled: true,
        order: entry.key,
      );
    }).toList();
    saveRules(defaults);
    return defaults;
  }

  static Future<void> saveRules(List<CuratedFeedRule> rules) async {
    final list = rules.map((r) => r.toJson()).toList();
    await GStorage.setting.put(SettingBoxKey.curatedFeedRules, list);
  }
}
