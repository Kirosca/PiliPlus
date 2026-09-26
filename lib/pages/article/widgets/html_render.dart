import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/widgets/image_viewer/hero.dart';
import 'package:PiliPlus/models/common/image_preview_type.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:material_ui/material_ui.dart';

Widget htmlRender({
  required BuildContext context,
  dom.Element? element,
  String? html,
  int? imgCount,
  List<String>? imgList,
  required double maxWidth,
}) {
  // if (kDebugMode) debugPrint('htmlRender');
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final extensions = [
    TagExtension(
      tagsToExtend: <String>{'img'},
      builder: (ExtensionContext extensionContext) {
        try {
          final Map<String, dynamic> attributes = extensionContext.attributes;
          final List<dynamic> key = attributes.keys.toList();
          String imgUrl = key.contains('src')
              ? attributes['src'] as String
              : attributes['data-src'] as String;
          imgUrl = imgUrl.contains('@') ? imgUrl.split('@').first : imgUrl;
          final bool isEmote = imgUrl.contains('/emote/');
          final bool isMall = imgUrl.contains('/mall/');
          if (isMall) {
            return const SizedBox.shrink();
          }

          String? clazz = attributes['class'];
          String? height = RegExp(
            r'max-height:(\d+)px',
          ).firstMatch('${attributes['style']}')?.group(1);
          if (clazz?.contains('cut-off') == true || height != null) {
            return ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: CachedNetworkImage(
                width: maxWidth,
                memCacheWidth: maxWidth.cacheSize(context),
                height: height != null ? double.parse(height) : null,
                imageUrl: ImageUtils.thumbnailUrl(imgUrl),
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox.shrink(),
              ),
            );
          }
          final width = isEmote ? 22.0 : maxWidth;
          Widget imageWidget = CachedNetworkImage(
            width: width,
            height: isEmote ? 22.0 : null,
            memCacheWidth: width.cacheSize(context),
            imageUrl: ImageUtils.thumbnailUrl(imgUrl, 60),
            fadeInDuration: const Duration(milliseconds: 120),
            fadeOutDuration: const Duration(milliseconds: 120),
            placeholder: (context, url) => Image.asset(Assets.loading),
          );

          if (!isEmote) {
            imageWidget = ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: imageWidget,
            );
          }

          return GestureDetector(
            onTap: () => PageUtils.imageView(
              imgList: [SourceModel(url: imgUrl)],
              quality: 60,
            ),
            child: fromHero(
              tag: imgUrl,
              child: imageWidget,
            ),
          );
        } catch (err) {
          if (kDebugMode) debugPrint('错误的HTML: $element');
          return const SizedBox.shrink();
        }
      },
    ),
  ];
  final style = {
    'html': Style(
      fontSize: FontSize(16),
      lineHeight: LineHeight.percent(175),
      letterSpacing: 0.35,
      color: colorScheme.onSurface,
    ),
    'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
    'a': Style(
      color: colorScheme.primary,
      textDecoration: TextDecoration.none,
    ),
    'br': Style(
      lineHeight: LineHeight.percent(-1),
    ),
    'p': Style(
      margin: Margins.only(bottom: 12),
      lineHeight: LineHeight.percent(175),
    ),
    'span': Style(
      height: Height(1.75),
    ),
    'div': Style(height: Height.auto()),
    'li > p': Style(
      display: Display.inline,
    ),
    'li': Style(
      padding: HtmlPaddings.only(bottom: 6),
      lineHeight: LineHeight.percent(170),
    ),
    'img': Style(
      margin: Margins.symmetric(vertical: 8),
      alignment: Alignment.center,
    ),
    'h1': Style(
      fontSize: FontSize(22),
      fontWeight: FontWeight.bold,
      margin: Margins.only(top: 20, bottom: 10),
      lineHeight: LineHeight.percent(140),
    ),
    'h2': Style(
      fontSize: FontSize(20),
      fontWeight: FontWeight.bold,
      margin: Margins.only(top: 18, bottom: 8),
      lineHeight: LineHeight.percent(140),
    ),
    'h3,h4,h5,h6': Style(
      fontSize: FontSize(17),
      fontWeight: FontWeight.w600,
      margin: Margins.only(top: 14, bottom: 6),
      lineHeight: LineHeight.percent(140),
    ),
    'blockquote': Style(
      margin: Margins.symmetric(vertical: 10),
      padding: HtmlPaddings.only(left: 12, right: 10, top: 8, bottom: 8),
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: Border(
        left: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.7),
          width: 3.5,
        ),
      ),
    ),
    'code': Style(
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: HtmlPaddings.symmetric(horizontal: 5, vertical: 2),
      fontFamily: 'monospace',
      fontSize: FontSize(14),
    ),
    'pre': Style(
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      padding: HtmlPaddings.all(12),
      margin: Margins.symmetric(vertical: 8),
    ),
    'hr': Style(
      margin: Margins.symmetric(vertical: 16),
      border: Border(
        bottom: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
    ),
    'figcaption': Style(
      fontSize: FontSize(13),
      color: colorScheme.outline,
      textAlign: TextAlign.center,
      margin: Margins.only(top: 4, bottom: 8),
    ),
    'strong': Style(fontWeight: FontWeight.bold),
    'figure': Style(
      margin: Margins.zero,
    ),
  };
  return element != null
      ? Html.fromElement(
          documentElement: element,
          extensions: extensions,
          style: style,
        )
      : Html(
          data: html,
          extensions: extensions,
          style: style,
        );
}
