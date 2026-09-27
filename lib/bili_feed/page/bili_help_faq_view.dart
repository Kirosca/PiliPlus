import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 四维筛选语法与 FAQ 常见问题页面
class BiliHelpFaqPage extends StatefulWidget {
  const BiliHelpFaqPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<BiliHelpFaqPage> createState() => _BiliHelpFaqPageState();
}

class _BiliHelpFaqPageState extends State<BiliHelpFaqPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('使用说明与 FAQ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '四维筛选语法'),
            Tab(text: '常见问题 (FAQ)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSyntaxView(context, colorScheme),
          _buildFaqView(context, colorScheme),
        ],
      ),
    );
  }

  /// 四维语法视图
  Widget _buildSyntaxView(BuildContext context, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 核心格式大卡片
        Card(
          elevation: 0,
          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '语法核心格式',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '关键词  -排除词  #分类标签  @指定UP主',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '真实范例：摄影 -入门 #ai @影视飓风',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  '• 标题必须含有【摄影】\n'
                  '• 标题严禁出现【入门】\n'
                  '• 视频标签必须包含【ai】\n'
                  '• 作者名必须包含【影视飓风】',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 四维拆解卡片
        _buildSectionHeader(Icons.dashboard_customize_outlined, '四维操作符详解', colorScheme),
        const SizedBox(height: 8),

        _buildOperatorTile(
          symbol: '空格',
          title: '正向词必含 (AND 逻辑)',
          desc: '标题必须同时包含各个关键词。支持多个词空格自由叠加。',
          example: '余华 活着',
          tip: '💡 技巧：整词匹配视频较少时，用空格把关键词拆开搜索，召回率大幅提升！',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 8),

        _buildOperatorTile(
          symbol: '- 词',
          title: '负向排除 (一票否决)',
          desc: '标题中一旦包含该词立即剔除。支持同时排除多个词。',
          example: 'Flutter -测试 -入门',
          tip: '例：搜索硬核技术，一键过滤大量“测试”与“入门”小白教程。',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 8),

        _buildOperatorTile(
          symbol: '# Tag',
          title: '标签穿透过滤',
          desc: '精准匹配视频所打的 Tag 标签。支持多个 # 标签同时指定（求交集）。',
          example: '#调色 #达芬奇 #教程',
          tip: '直接命中 UP 主打上的精细分类，不依赖标题是否提及。',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 8),

        _buildOperatorTile(
          symbol: '@ UP',
          title: '指定作者白名单',
          desc: '仅保留指定 UP 主的视频。支持多个 @UP 主同时输入（求并集）。',
          example: '@影视飓风 @mrbeast',
          tip: '输入多个作者时，只要是其中任意一位 UP 主的视频均会保留。',
          colorScheme: colorScheme,
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '说明：当前去噪引擎专为移动端极速执行优化，仅支持「空格」、「-」、「#」、「@」四类符号，暂未引入「|」或语法或复杂括号嵌套。如需检索多个不同主题，建议分条创建独立规则。',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        _buildSectionHeader(Icons.compare_arrows_rounded, '进阶：整词 vs 空格对比', colorScheme),
        const SizedBox(height: 8),

        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '目标视频：《余华大师课：讲述〈活着〉的创作历程》',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                _buildCompareRow('余华大师课', true, '匹配（整串字序完全一致）', colorScheme),
                _buildCompareRow('余华大师课活着', false, '不匹配（原标题中间有冒号等其他字）', colorScheme),
                _buildCompareRow('余华 活着', true, '匹配（两词独立命中，顺序无限制）', colorScheme),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  /// FAQ 常见问题视图
  Widget _buildFaqView(BuildContext context, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _buildFaqItem(
          icon: Icons.filter_alt_off_outlined,
          question: '为什么搜出来的视频数量变少了？',
          answer:
              '这是定制版四维去噪引擎的核心作用。原版 B 站搜索常混入大量无关推荐、引流切片与蹭热度视频。\n\n'
              '定制版在手机本地执行了 0 毫秒物理过滤与深度自动翻页，只有 100% 符合你指定条件的高质量视频才会显示，为你彻底净化搜索环境。',
          colorScheme: colorScheme,
        ),
        _buildFaqItem(
          icon: Icons.shield_outlined,
          question: '安卓手机安装提示风险 / 报毒？',
          answer:
              '请放心使用！本软件为个人开源免费定制版，未向各手机厂商商业应用商店付费上架，因此在安装时会触发系统常规的“未备案/未知来源”安全提示。\n\n'
              '源码完全透明公开，无任何广告、后门或恶意代码。安装时可放心选择“继续安装 / 信任此应用”，或临时开启飞行模式断网安装。',
          colorScheme: colorScheme,
        ),
        _buildFaqItem(
          icon: Icons.phone_iphone_rounded,
          question: '苹果 iOS 能否安装？如何安装？',
          answer:
              'iOS 完整支持！推荐通过以下途径安装定制版 IPA：\n'
              '1. 【巨魔商店 (TrollStore)】：永久免签名、支持自由更新与后台运行，体验最佳；\n'
              '2. 【个人自签名】：通过 AltStore、Sideloadly 或牛蛙助手，使用免费 Apple ID 签名安装（7天需重签）；\n'
              '3. 【企业或个人开发者证书】：可直接在线分发安装。',
          colorScheme: colorScheme,
        ),
        _buildFaqItem(
          icon: Icons.auto_awesome_motion_outlined,
          question: '“选推”流与“推荐”流有什么区别？',
          answer:
              '• 官方推荐流：由 B 站算法推送，容易受到近期点击和信息流算法影响；\n'
              '• 自定义选推流：完全由你掌控！在【设置 -> 选推规则管理】中配置你关注的关键词、Tag 或 UP 主。系统会自动按等比平分抽取各个规则的内容，并打乱呈现，打造专属精品信息流。',
          colorScheme: colorScheme,
        ),
        _buildFaqItem(
          icon: Icons.code_rounded,
          question: '是否支持「|」或语法或复杂逻辑嵌套？',
          answer:
              '目前不支持「|」或语法及括号逻辑嵌套。\n\n'
              '当前过滤引擎专为手机端高性能设计，遵循四维符号规范：\n'
              '• 【空格】：正向多词必含（AND 逻辑，每个词均须命中标题）\n'
              '• 【-】：负向排除词（NOT 逻辑，命中立即一票否决）\n'
              '• 【#】：分类标签过滤（精准匹配视频 Tag）\n'
              '• 【@】：指定 UP 主白名单（匹配视频发布者）\n\n'
              '若需要检索多个不同分类，建议在【选推规则管理】中建立多条独立规则，选推流会自动轮询打乱呈现。',
          colorScheme: colorScheme,
        ),
        _buildFaqItem(
          icon: Icons.settings_backup_restore_rounded,
          question: '配置文件在哪里导入与备份？',
          answer:
              '路径非常简单：进入应用首页 -> 右上角个人头像【我的】->【关于页面】-> 点击【导入/导出设置】。\n\n'
              '支持一键导出全部偏好与选推规则至剪贴板或本地文件，重装后可秒级还原。',
          colorScheme: colorScheme,
        ),
        _buildFaqItem(
          icon: Icons.bug_report_outlined,
          question: '遇到 Bug 或有新的筛选建议如何反馈？',
          answer:
              '欢迎在 B 站专栏下方留言，或前往项目的 GitHub 仓库提交 Issue 反馈。\n\n'
              '如果你觉得这个定制版为你节省了时间，欢迎前往爱发电支持作者，喝杯咖啡～',
          colorScheme: colorScheme,
          actionButton: OutlinedButton.icon(
            onPressed: () => PageUtils.launchURL(Constants.afdianUrl),
            icon: const Icon(Icons.favorite, size: 16, color: Color(0xFFFD5674)),
            label: const Text('前往爱发电支持作者'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorTile({
    required String symbol,
    required String title,
    required String desc,
    required String example,
    required String tip,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    symbol,
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(desc, style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '示例: $example',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 4),
            Text(tip, style: TextStyle(fontSize: 11.5, color: colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareRow(String query, bool match, String reason, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            match ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: match ? Colors.green : colorScheme.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.5, color: colorScheme.onSurface),
                children: [
                  TextSpan(
                    text: '【$query】',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: ' -> $reason',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({
    required IconData icon,
    required String question,
    required String answer,
    required ColorScheme colorScheme,
    Widget? actionButton,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(icon, color: colorScheme.primary, size: 22),
        title: Text(
          question,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (actionButton != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: actionButton),
          ],
        ],
      ),
    );
  }
}

/// 底部弹出四维语法速查半屏面板
abstract final class BiliHelpFaqSheet {
  static void show(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            '四维精准去噪语法速查',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Get.toNamed('/helpFaq');
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('完整文档'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '格式：关键词  -排除词  #分类标签  @指定UP主',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '示例：摄影 -入门 #ai @影视飓风',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickItem('空格', '正向必含 (AND)', '余华 活着', '多词全部包含', colorScheme),
                      _buildQuickItem('- 排除', '一票否决', 'Flutter -测试 -入门', '标题绝不含该词', colorScheme),
                      _buildQuickItem('# 标签', '标签穿透', '#调色 #达芬奇', '视频标签精准交集', colorScheme),
                      _buildQuickItem('@ UP', '指定作者', '@影视飓风 @mrbeast', '作者白名单并集', colorScheme),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '💡 支持「空格」、「-」、「#」、「@」四类符号，暂不支持「|」或语法。多词用空格分隔表示必须全部包含。',
                          style: TextStyle(fontSize: 12, color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildQuickItem(
    String badge,
    String title,
    String example,
    String desc,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(desc, style: TextStyle(fontSize: 11.5, color: colorScheme.outline)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '示例: $example',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
