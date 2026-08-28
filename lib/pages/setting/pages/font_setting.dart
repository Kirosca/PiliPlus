import 'dart:io';

import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/extension/box_ext.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class FontSettingPage extends StatefulWidget {
  const FontSettingPage({super.key});

  @override
  State<FontSettingPage> createState() => _FontSettingPageState();
}

class _FontSettingPageState extends State<FontSettingPage> {
  String? _selectedFont = Pref.appFont;
  int _selectedWeight = Pref.appFontWeight;
  double _selectedScale = Pref.defaultTextScale;

  late final List<String> _fonts;
  late ColorScheme colorScheme;

  @override
  void initState() {
    super.initState();
    _fonts = FontUtils.getFont().toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorScheme = ColorScheme.of(context);
  }

  void _saveFontSetting() {
    GStorage.setting.putAllNE({
      SettingBoxKey.appFont: _selectedFont,
      SettingBoxKey.appFontWeight: _selectedWeight,
      SettingBoxKey.defaultTextScale: _selectedScale,
    });

    Get
      ..back()
      ..updateMyAppTheme();
  }

  /// ref [Typography._withPlatform]
  /// ref [Material]
  static final String? _kFontFamily = (switch (defaultTargetPlatform) {
    .iOS => Typography.whiteCupertino,
    .android || .fuchsia => Typography.whiteMountainView,
    .windows => Typography.whiteRedmond,
    .macOS => Typography.whiteRedwoodCity,
    .linux => Typography.whiteHelsinki,
  }).bodyMedium?.fontFamily;

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _selectedFont = null;
              _selectedWeight = -1;
              _selectedScale = 1;
            }),
            child: const Text('重置'),
          ),
          TextButton(
            onPressed: _saveFontSetting,
            child: const Text('确定'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  'abcdefghijklmnopqrstuvwxyz\n'
                  'ABCDEFGHIJKLMNOPQRSTUVWXYZ\n'
                  '1234567890.:,;\'"(!?)+-*/=\n'
                  '${Platform.isWindows
                      ? "中国智造，惠及全球"
                      : Platform.isMacOS || Platform.isIOS
                      ? "汉体书写信息技术标准相容"
                      : "我能吞下玻璃而不伤身体"}\n\n'
                  '注：部分字体可能无法应用',
                  style: TextStyle(
                    fontFamily: _selectedFont ?? _kFontFamily,
                    fontWeight: _selectedWeight == -1
                        ? null
                        : FontWeight.values[_selectedWeight],
                    fontSize: 14 * _selectedScale,
                  ),
                ),
              ),
            ),
            _buildItem(
              Row(
                mainAxisSize: .min,
                children: [
                  const Text('字体：', style: TextStyle(fontWeight: .bold)),
                  Expanded(
                    child: DropdownButton<String?>(
                      focusColor: Colors.transparent,
                      value: _selectedFont,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(value: null, child: Text('默认')),
                        ...FontUtils.customFonts.keys.map(
                          (font) => _DropdownMenuItem(
                            value: font,
                            onRemove: () {
                              FontUtils.removeFont(font);
                              if (_selectedFont == font) {
                                _selectedFont = null;
                              }
                              setState(() {});
                            },
                            child: Text(font.split('/').last),
                          ),
                        ),
                        ..._fonts.map(
                          (font) => DropdownMenuItem(
                            value: font,
                            child: Text(
                              font,
                              style: TextStyle(fontFamily: font),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value != null &&
                            FontUtils.customFonts.containsKey(value)) {
                          await FontUtils.loadFontIfNecessary(value);
                          if (!mounted) return;
                        }
                        setState(
                          () => _selectedFont == value
                              ? _selectedFont = null
                              : _selectedFont = value,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const .only(left: 5),
                    child: iconButton(
                      size: 34,
                      iconSize: 20,
                      tooltip: '导入',
                      context: context,
                      onPressed: () async {
                        SmartDialog.showLoading();
                        final font = await FontUtils.pickFonts();
                        SmartDialog.dismiss();
                        if (!mounted) return;
                        if (font != null) {
                          _selectedFont = font;
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  Padding(
                    padding: const .only(left: 5),
                    child: iconButton(
                      size: 34,
                      iconSize: 20,
                      tooltip: '清空',
                      context: context,
                      onPressed: () async {
                        SmartDialog.showLoading();
                        _selectedFont = null;
                        await FontUtils.clearFonts();
                        SmartDialog.dismiss();
                        if (!mounted) return;
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear_all),
                    ),
                  ),
                ],
              ),
            ),
            _buildItem(
              Row(
                children: [
                  const Text('字重：', style: TextStyle(fontWeight: .bold)),
                  const SizedBox(
                    width: 40,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '默认/\n'),
                          TextSpan(
                            text: 'w100',
                            style: TextStyle(fontWeight: .w100),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      padding: .zero,
                      value: _selectedWeight.toDouble(),
                      min: -1,
                      max: 8,
                      divisions: 9,
                      label: _selectedWeight == -1
                          ? '默认'
                          : 'w${(_selectedWeight + 1) * 100}',
                      onChanged: (value) {
                        setState(() => _selectedWeight = value.toInt());
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 50,
                    child: Align(
                      alignment: .centerRight,
                      child: Text('w900', style: TextStyle(fontWeight: .w900)),
                    ),
                  ),
                ],
              ),
            ),
            _buildItem(
              Row(
                children: [
                  const Text('字号：', style: TextStyle(fontWeight: .bold)),
                  const SizedBox(
                    width: 40,
                    child: Text('小', style: TextStyle(fontSize: 11.9)),
                  ),
                  Expanded(
                    child: Slider(
                      padding: .zero,
                      value: _selectedScale,
                      min: 0.85,
                      max: 1.6,
                      divisions: 15,
                      secondaryTrackValue: 1,
                      label: _selectedScale == 1.0
                          ? '默认'
                          : _selectedScale.toStringAsFixed(2),
                      onChanged: (value) =>
                          setState(() => _selectedScale = value.toPrecision(2)),
                    ),
                  ),
                  const SizedBox(
                    width: 50,
                    child: Align(
                      alignment: .centerRight,
                      child: Text('大', style: TextStyle(fontSize: 22.4)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Widget child) {
    return Container(
      padding: const .symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
        ),
      ),
      child: child,
    );
  }
}

class _DropdownMenuItem<T> extends DropdownMenuItem<T> {
  const _DropdownMenuItem({
    super.key,
    super.onTap,
    super.value,
    super.enabled,
    super.alignment,
    required super.child,
    required this.onRemove,
  });

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: super.build(context)),
        iconButton(
          size: 38,
          iconSize: 22,
          tooltip: '移除',
          onPressed: () {
            if (Get.routing.route is! GetPageRoute) Get.back();
            onRemove();
          },
          icon: const Icon(Icons.clear),
        ),
      ],
    );
  }
}
