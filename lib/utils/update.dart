import 'dart:io' show Platform;

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';

abstract final class Update {
  // 检查更新
  static Future<void> checkUpdate([bool isAuto = true]) async {
    if (kDebugMode) return;
    SmartDialog.dismiss();
    try {
      final res = await Request().get(
        Api.latestApp,
        options: Options(
          headers: {'user-agent': BrowserUa.mob},
          extra: {'account': const NoAccount()},
        ),
      );
      if (res.data is Map || res.data.isEmpty) {
        if (!isAuto) {
          SmartDialog.showToast('检查更新失败，GitHub接口未返回数据，请检查网络');
        }
        return;
      }
      final data = res.data[0];
      final int latest =
          DateTime.parse(data['created_at']).millisecondsSinceEpoch ~/ 1000;
      if (BuildConfig.buildTime >= latest) {
        if (!isAuto) {
          SmartDialog.showToast('已是最新版本');
        }
      } else {
        _showDialog(data, isAuto: isAuto);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('failed to check update: $e');
    }
  }

  // 模拟新版本弹窗（功能测试，长按版本号触发）
  static void showTestUpdateDialog() {
    final Map<String, dynamic> testData = {
      'tag_name': 'v2.1.2-v4',
      'name': 'PiliPlus v2.1.2-v4 标题筛选定制版',
      'created_at': '2026-08-29T13:18:09Z',
      'body': r'''### 🌟 核心更新

#### 1. 四维精准搜索去噪体系
* **语法格式**：`关键词 -排除词 #分类标签 @指定UP主`
* **真实示例**：`摄影 -入门 #调色 @影视飓风`
* **规则说明**：
  * 标题必须含有 **【摄影】**；
  * 标题严禁出现 **【入门】**；
  * 视频标签必须包含 **【调色】**；
  * 作者名包含 **【`@影视飓风`】**（支持多个 `@UP主`，如【`@A` `@B`】是出现包含`@A`或`@B`的视频）；
  * 所有符号均可多个自由叠加组合。

#### 2. 修复与体验优化
* **更新渠道修复**：修复更新检测重定向，应用内更新新增 `Gitee` 国内下载通道。

#### 3. 同步官方上游最新特性 (70+ Commits)
* **音频与后台播放**：优化后台仅听音频模式、支持自定义音轨加载优先级、修复后台音频服务控制与休眠定时中断问题；
* **网络与编码**：支持为 Wi-Fi 与移动网络**独立设置默认视频编码**（HEVC / AVC / AV1）；
* **字体管理**：新增**自定义字体管理面板**，支持导入本地字体与智能回退系统默认；
* **内容过滤**：新增**过滤充电专属视频**推荐；
* **播放与交互**：分P选集列表新增序号索引、细化弹幕不透明度/字号调节档位、重构睡眠定时关闭面板；
* **数据与同步**：修复 WebDAV 多账号同步绑定、支持复制视频缓存 URI 链接；
* **底层适配**：全线升级至 Flutter 3.47.2 引擎，加固 iOS/Android 双端编译构建。

---

### ❤️ 投喂与支持
如果觉得好用，欢迎前往 [爱发电 (Afdian)](https://afdian.com/a/Kirosca) 投喂作者～''',
      'assets': [
        {
          'name': 'app-release.apk',
          'browser_download_url':
              'https://github.com/Kirosca/PiliPlus/releases/download/v2.1.2-v4/app-release.apk',
        },
        {
          'name': 'PiliPlus_ios.ipa',
          'browser_download_url':
              'https://github.com/Kirosca/PiliPlus/releases/download/v2.1.2-v4/PiliPlus_ios.ipa',
        },
      ],
    };

    _showDialog(
      testData,
      isAuto: true,
      title: '🎉 发现新版本 (功能测试)',
    );
  }

  // 显示更新弹窗
  static void _showDialog(
    Map data, {
    bool isAuto = false,
    String? title,
  }) {
    SmartDialog.show(
      animationType: SmartAnimationType.centerFade_otherSlide,
      builder: (context) {
        final colorScheme = ColorScheme.of(context);
        final rawBody = (data['body'] as String?) ?? '';
        final tagName = (data['tag_name'] as String?) ?? '';
        final releaseName = (data['name'] as String?) ?? '';

        return AlertDialog(
          title: Text(title ?? '🎉 发现新版本 '),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 版本号与标题
                    if (tagName.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tagName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          if (releaseName.isNotEmpty && releaseName != tagName) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                releaseName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Markdown 渲染更新说明
                    _buildMarkdownBody(rawBody, colorScheme),

                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => PageUtils.launchURL(
                        '${Constants.sourceCodeUrl}/commits/main',
                      ),
                      child: Text(
                        "点击查看完整更新(commit)内容",
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 10,
            top: 4,
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => onDownload(data),
                      icon: const Icon(FontAwesomeIcons.github, size: 18),
                      label: const Text('GitHub'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        SmartDialog.dismiss();
                        PageUtils.launchURL(Constants.giteeReleasesUrl);
                      },
                      icon: const Icon(CustomIcons.gitee, size: 18),
                      label: const Text('Gitee'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isAuto) ...[
                      TextButton(
                        onPressed: () {
                          SmartDialog.dismiss();
                          if (title?.contains('测试') == true) {
                            SmartDialog.showToast('测试提示：已模拟点击【不再提醒】');
                          } else {
                            GStorage.setting.put(SettingBoxKey.autoUpdate, false);
                          }
                        },
                        child: Text(
                          '不再提醒',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: SmartDialog.dismiss,
                      child: Text(
                        '取消',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // 解析并渲染 Markdown 内容
  static Widget _buildMarkdownBody(String rawBody, ColorScheme colorScheme) {
    if (rawBody.trim().isEmpty) return const SizedBox.shrink();

    final List<Widget> widgets = [];
    final lines = rawBody.split('\n');
    bool lastWasEmpty = false;

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        if (!lastWasEmpty) {
          widgets.add(const SizedBox(height: 6));
          lastWasEmpty = true;
        }
        continue;
      }
      lastWasEmpty = false;

      // H4
      if (trimmed.startsWith('#### ')) {
        final text = trimmed.substring(5);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        );
        continue;
      }

      // H3
      if (trimmed.startsWith('### ')) {
        final text = trimmed.substring(4);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        );
        continue;
      }

      // H1 & H2
      if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        final text = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        );
        continue;
      }

      // Divider
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: colorScheme.outlineVariant,
            ),
          ),
        );
        continue;
      }

      // Blockquote
      if (trimmed.startsWith('> ')) {
        final quoteText = trimmed.substring(2);
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 3),
              ),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Text.rich(
              TextSpan(children: _parseInlineSpans(quoteText, colorScheme)),
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: colorScheme.outline,
              ),
            ),
          ),
        );
        continue;
      }

      // Bullets (*, -, +)
      final leadingSpaces = rawLine.length - rawLine.trimLeft().length;
      final isSubBullet = leadingSpaces >= 2 &&
          (trimmed.startsWith('* ') || trimmed.startsWith('- ') || trimmed.startsWith('+ '));
      final isTopBullet = !isSubBullet &&
          (trimmed.startsWith('* ') || trimmed.startsWith('- ') || trimmed.startsWith('+ '));

      if (isTopBullet || isSubBullet) {
        final content = trimmed.substring(2).trim();
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: isSubBullet ? 18.0 : 4.0,
              top: 2,
              bottom: 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSubBullet ? '◦ ' : '• ',
                  style: TextStyle(
                    color: isSubBullet ? colorScheme.outline : colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.45,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(content, colorScheme),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Numbered list (e.g. 1. 2.)
      final numMatch = RegExp(r'^(\d+\.)\s+(.+)').firstMatch(trimmed);
      if (numMatch != null) {
        final numPrefix = numMatch.group(1)!;
        final content = numMatch.group(2)!;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: leadingSpaces >= 2 ? 18.0 : 4.0,
              top: 2,
              bottom: 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numPrefix ',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.45,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(content, colorScheme),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Normal paragraph
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(
            TextSpan(
              children: _parseInlineSpans(trimmed, colorScheme),
            ),
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  // 解析行内富文本 (链接、加粗、代码块)
  static List<InlineSpan> _parseInlineSpans(
    String text,
    ColorScheme colorScheme, {
    bool isBold = false,
  }) {
    final List<InlineSpan> spans = [];
    final pattern = RegExp(
      r'(\[([^\]]+)\]\((https?://[^\)]+)\))|(\*\*([^*]+)\*\*)|(`([^`]+)`)',
    );

    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        );
      }

      if (match.group(1) != null) {
        // Link [text](url)
        final linkText = match.group(2)!;
        final linkUrl = match.group(3)!;
        spans.add(
          TextSpan(
            text: linkText,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.primary,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => PageUtils.launchURL(linkUrl),
          ),
        );
      } else if (match.group(4) != null) {
        // Bold **text**
        final boldContent = match.group(5)!;
        spans.addAll(_parseInlineSpans(boldContent, colorScheme, isBold: true));
      } else if (match.group(6) != null) {
        // Code `code`
        final codeText = match.group(7)!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 0.6,
                ),
              ),
              child: Text(
                codeText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
      );
    }

    return spans;
  }

  // 下载适用于当前系统的安装包
  static Future<void> onDownload(Map data, {String? ext}) async {
    SmartDialog.dismiss();
    try {
      if (data['assets'] is List && (data['assets'] as List).isNotEmpty) {
        final List assets = data['assets'];

        if (Platform.isAndroid) {
          for (Map<String, dynamic> item in assets) {
            final String name = item['name'] ?? '';
            if (name.endsWith('.apk')) {
              PageUtils.launchURL(item['browser_download_url']);
              return;
            }
          }
        } else if (Platform.isIOS) {
          for (Map<String, dynamic> item in assets) {
            final String name = item['name'] ?? '';
            if (name.endsWith('.ipa')) {
              PageUtils.launchURL(item['browser_download_url']);
              return;
            }
          }
        } else {
          for (Map<String, dynamic> item in assets) {
            final String name = item['name'] ?? '';
            if (name.contains(Platform.operatingSystem) &&
                (ext == null || ext.isEmpty ? true : name.endsWith(ext))) {
              PageUtils.launchURL(item['browser_download_url']);
              return;
            }
          }
        }
      }
      throw UnsupportedError('platform not found');
    } catch (e) {
      if (kDebugMode) debugPrint('download error: $e');
      PageUtils.launchURL('${Constants.sourceCodeUrl}/releases/latest');
    }
  }
}
