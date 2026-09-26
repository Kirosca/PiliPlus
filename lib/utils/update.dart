import 'package:PiliPlus/bili_feed/core/bili_update.dart';

/// 上游更新门面类，所有具体实现已完全解耦并委托至 [BiliUpdate]
abstract final class Update {
  /// 检查更新
  static Future<void> checkUpdate([bool isAuto = true]) =>
      BiliUpdate.checkUpdate(isAuto);

  /// 模拟新版本弹窗（功能测试，长按版本号触发）
  static void showTestUpdateDialog() =>
      BiliUpdate.showTestUpdateDialog();

  /// 下载适用于当前系统的安装包
  static Future<void> onDownload(Map data, {String? ext}) =>
      BiliUpdate.onDownload(data, ext: ext);
}
