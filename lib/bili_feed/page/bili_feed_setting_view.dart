import 'package:PiliPlus/bili_feed/model/bili_feed_rule.dart';
import 'package:PiliPlus/bili_feed/page/bili_feed_controller.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class BiliFeedSettingPage extends StatefulWidget {
  const BiliFeedSettingPage({super.key});

  @override
  State<BiliFeedSettingPage> createState() => _BiliFeedSettingPageState();
}

class _BiliFeedSettingPageState extends State<BiliFeedSettingPage> {
  List<BiliFeedRule> rules = [];
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void dispose() {
    if (_hasChanged) {
      BiliFeedStorage.clearLastFeedItems();
      if (Get.isRegistered<BiliFeedController>()) {
        Get.find<BiliFeedController>().onRulesChanged();
      }
    }
    super.dispose();
  }

  void _loadRules() {
    rules = BiliFeedStorage.getRules();
    setState(() {});
  }

  Future<void> _saveRules() async {
    _hasChanged = true;
    for (int i = 0; i < rules.length; i++) {
      rules[i].order = i;
    }
    await BiliFeedStorage.saveRules(rules);
  }

  void _addOrEditRule([BiliFeedRule? existingRule]) {
    final textController =
        TextEditingController(text: existingRule?.keyword ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingRule == null ? '添加选推规则' : '编辑选推规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '例: TED演讲 或 #余华 或 @影视飓风',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '支持四维语法：空格(必含)、-词(排除)、@UP主(作者)、#标签(Tag)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isEmpty) {
                  SmartDialog.showToast('规则关键词不能为空');
                  return;
                }
                Navigator.of(context).pop();
                if (existingRule != null) {
                  existingRule.keyword = text;
                } else {
                  rules.add(
                    BiliFeedRule(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      keyword: text,
                      enabled: true,
                      order: rules.length,
                    ),
                  );
                }
                _saveRules();
                setState(() {});
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _deleteRule(int index) {
    rules.removeAt(index);
    _saveRules();
    setState(() {});
    SmartDialog.showToast('已删除');
  }

  void _resetDefaults() {
    rules = BiliFeedStorage.defaultKeywords.asMap().entries.map((entry) {
      return BiliFeedRule(
        id: 'default_${entry.key}',
        keyword: entry.value,
        enabled: true,
        order: entry.key,
      );
    }).toList();
    _saveRules();
    setState(() {});
    SmartDialog.showToast('已重置为默认规则');
  }

  void _showImportExport() {
    showImportExportDialog<dynamic>(
      context,
      title: '选推规则',
      enableInput: false,
      localFileName: () => 'curated_feed_rules',
      onExport: () => Utils.jsonEncoder.convert(
        rules.map((r) => r.toJson()).toList(),
      ),
      onImport: (dynamic json) async {
        final List list;
        if (json is List) {
          list = json;
        } else if (json is Map && json['curatedFeedRules'] is List) {
          list = json['curatedFeedRules'] as List;
        } else if (json is Map && json['rules'] is List) {
          list = json['rules'] as List;
        } else {
          throw '数据格式错误，须为规则数组';
        }
        final newRules = <BiliFeedRule>[];
        for (int i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is Map) {
            final rule = BiliFeedRule.fromJson(Map<String, dynamic>.from(item));
            rule.order = i;
            newRules.add(rule);
          } else if (item is String && item.trim().isNotEmpty) {
            newRules.add(BiliFeedRule(
              id: '${DateTime.now().microsecondsSinceEpoch}_$i',
              keyword: item.trim(),
              order: i,
            ));
          }
        }
        if (newRules.isEmpty) {
          throw '未找到有效的选推规则';
        }
        rules = newRules;
        await _saveRules();
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('选推规则管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export_outlined),
            tooltip: '导入/导出规则',
            onPressed: _showImportExport,
          ),
          TextButton(
            onPressed: _resetDefaults,
            child: const Text('重置默认'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      fab: Padding(
        padding: EdgeInsets.only(
          right: kFloatingActionButtonMargin + viewPadding.right,
          bottom: kFloatingActionButtonMargin + viewPadding.bottom,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _addOrEditRule(),
          icon: const Icon(Icons.add),
          label: const Text('添加规则'),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '选推推荐池规则说明',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• 启用多个规则时，系统按等比平分抽取各个规则的内容并打乱呈现。\n'
                        '• 某个关键词见底后，会自动从头循环补充推荐池。\n'
                        '• 点击条目可编辑，长按右侧手柄可拖拽排序。',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverReorderableList(
            itemCount: rules.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = rules.removeAt(oldIndex);
              rules.insert(newIndex, item);
              _saveRules();
              setState(() {});
            },
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                key: ValueKey(rule.id),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_indicator_rounded),
                  ),
                  title: Text(
                    rule.keyword,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: rule.enabled ? null : TextDecoration.lineThrough,
                      color: rule.enabled ? null : colorScheme.outline,
                    ),
                  ),
                  onTap: () => _addOrEditRule(rule),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: rule.enabled,
                        onChanged: (val) {
                          rule.enabled = val;
                          _saveRules();
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: colorScheme.error,
                        onPressed: () => _deleteRule(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 80 + viewPadding.bottom),
          ),
        ],
      ),
    );
  }
}

// 别名保证向后兼容
typedef CuratedFeedSettingPage = BiliFeedSettingPage;
