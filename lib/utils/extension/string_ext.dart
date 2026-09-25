import 'package:PiliPlus/bili_feed/bili_feed_hook.dart';

final _regExp = RegExp("^(http:)?//", caseSensitive: false);

extension NullableStringExt on String? {
  String get http2https => this?.replaceFirst(_regExp, "https://") ?? '';

  bool get isNullOrEmpty => this == null || this!.isEmpty;

  String toSimplified() =>
      this == null ? '' : BiliFeedHook.toSimplified(this!);
}

extension StringExt on String {
  String toSimplified() => BiliFeedHook.toSimplified(this);

  String subLength(int length) {
    if (this.length < length) return this;
    return substring(0, length);
  }
}
