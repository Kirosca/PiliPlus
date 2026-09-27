import 'dart:async';
import 'dart:io' show Directory, File, Platform, Process;

import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path/path.dart' as path;

/// 离线缓存视频无损合并与导出服务
abstract final class BiliExportService {
  static const MethodChannel _channel = MethodChannel('com.example.piliplus/export');

  /// 清洗文件名，过滤系统非法字符
  static String sanitizeFileName(String name) {
    var clean = name
        .replaceAll(RegExp(r'[\/\\:\*\?"<>\|\r\n\t]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length > 120) {
      clean = clean.substring(0, 120).trim();
    }
    return clean.isEmpty ? 'video_${DateTime.now().millisecondsSinceEpoch}' : clean;
  }

  /// 构建规范导出文件名（以视频完整标题为准，支持分P与剧集集数）
  static String buildExportFileName(BiliDownloadEntryInfo entry) {
    // 1. 优先获取视频主标题
    String mainTitle = entry.title.trim();
    if (mainTitle.isEmpty) {
      mainTitle = entry.showTitle.trim();
    }
    if (mainTitle.isEmpty) {
      mainTitle = 'video_${DateTime.now().millisecondsSinceEpoch}';
    }

    // 2. 处理番剧/影视 (ep)
    if (entry.ep case final ep?) {
      final epPart = ep.showTitle?.trim() ??
          (ep.index.isNotEmpty ? '第${ep.index}话 ${ep.indexTitle}'.trim() : '');
      if (epPart.isNotEmpty && !mainTitle.contains(epPart)) {
        return sanitizeFileName('${mainTitle}_$epPart');
      }
      return sanitizeFileName(mainTitle);
    }

    // 3. 处理分 P 视频
    final pageData = entry.pageData;
    if (pageData != null) {
      final page = pageData.page;
      final part = pageData.part?.trim();

      final hasDistinctPart = part != null &&
          part.isNotEmpty &&
          part != mainTitle &&
          part != '$page';

      if (page > 1) {
        if (hasDistinctPart) {
          return sanitizeFileName('${mainTitle}_P${page}_$part');
        } else {
          return sanitizeFileName('${mainTitle}_P$page');
        }
      } else if (hasDistinctPart) {
        return sanitizeFileName('${mainTitle}_P1_$part');
      }
    }

    // 4. 普通单视频：直接为完整视频标题
    return sanitizeFileName(mainTitle);
  }

  /// 获取导出目标公共目录
  static Future<String> getExportDirectory() async {
    if (Platform.isAndroid) {
      try {
        final dir = await _channel.invokeMethod<String>('getPublicDownloadDir');
        if (dir != null && dir.isNotEmpty) {
          return dir;
        }
      } catch (_) {}
      return '/storage/emulated/0/Download/PiliPlus';
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      return path.join(userProfile, 'Downloads', 'PiliPlus');
    } else {
      final home = Platform.environment['HOME'] ?? '';
      return path.join(home, 'Downloads', 'PiliPlus');
    }
  }

  /// 为导出的文件生成不重名的完整输出路径
  static Future<String> getUniqueOutputPath(String baseDir, String fileName) async {
    final dir = Directory(baseDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    String outPath = path.join(baseDir, '$fileName.mp4');
    int counter = 1;
    while (File(outPath).existsSync()) {
      outPath = path.join(baseDir, '${fileName}_$counter.mp4');
      counter++;
    }
    return outPath;
  }

  /// 根据下载条目定位视频轨与音频轨路径
  static (File videoFile, File? audioFile) resolveMediaFiles(BiliDownloadEntryInfo entry) {
    final qualityDir = path.join(entry.entryDirPath, entry.typeTag);

    // DASH 分离轨 (video.m4s + audio.m4s)
    final vDash = File(path.join(qualityDir, PathUtils.videoNameType2));
    final aDash = File(path.join(qualityDir, PathUtils.audioNameType2));
    if (vDash.existsSync()) {
      return (vDash, aDash.existsSync() ? aDash : null);
    }

    // 单文件 MP4 (0.mp4)
    final vSingle = File(path.join(qualityDir, PathUtils.videoNameType1));
    if (vSingle.existsSync()) {
      return (vSingle, null);
    }

    // 尝试在 entry 根目录查找
    final vFallback = File(path.join(entry.entryDirPath, PathUtils.videoNameType2));
    final aFallback = File(path.join(entry.entryDirPath, PathUtils.audioNameType2));
    return (vFallback, aFallback.existsSync() ? aFallback : null);
  }

  /// 执行无损封装合并核心流程
  static Future<bool> muxOrCopy({
    required File videoFile,
    File? audioFile,
    required String outputPath,
  }) async {
    if (!videoFile.existsSync()) {
      return false;
    }

    // 如果没有独立音频轨（如本身就是完整 0.mp4），直接快速拷贝
    if (audioFile == null || !audioFile.existsSync() || audioFile.lengthSync() == 0) {
      await videoFile.copy(outputPath);
      return true;
    }

    if (Platform.isAndroid) {
      try {
        final bool? success = await _channel.invokeMethod<bool>('muxVideoAudio', {
          'videoPath': videoFile.path,
          'audioPath': audioFile.path,
          'outputPath': outputPath,
        });
        return success == true;
      } catch (e) {
        debugPrint('Android Muxer Error: $e');
        return false;
      }
    } else {
      // 桌面端调用 ffmpeg 无损混流
      try {
        final res = await Process.run('ffmpeg', [
          '-y',
          '-i',
          videoFile.path,
          '-i',
          audioFile.path,
          '-c',
          'copy',
          '-movflags',
          'faststart',
          outputPath,
        ]);
        if (res.exitCode == 0) {
          return true;
        }
      } catch (_) {}

      // 若未检测到 ffmpeg，回退为直接拷贝视频文件
      await videoFile.copy(outputPath);
      return true;
    }
  }

  /// 导出单个离线视频
  static Future<bool> exportSingle(
    BiliDownloadEntryInfo entry, {
    bool showToast = true,
  }) async {
    final (videoFile, audioFile) = resolveMediaFiles(entry);
    if (!videoFile.existsSync()) {
      if (showToast) SmartDialog.showToast('未找到缓存媒体文件，无法导出');
      return false;
    }

    if (showToast) {
      SmartDialog.showLoading(msg: '正在无损合并导出...');
    }

    try {
      final exportDir = await getExportDirectory();
      final safeName = buildExportFileName(entry);
      final outPath = await getUniqueOutputPath(exportDir, safeName);

      final success = await muxOrCopy(
        videoFile: videoFile,
        audioFile: audioFile,
        outputPath: outPath,
      );

      if (showToast) {
        SmartDialog.dismiss();
        if (success) {
          SmartDialog.showToast('导出成功！已存至：$outPath', displayTime: const Duration(seconds: 4));
        } else {
          SmartDialog.showToast('导出失败，请检查存储权限与空间');
        }
      }
      return success;
    } catch (e) {
      if (showToast) {
        SmartDialog.dismiss();
        SmartDialog.showToast('导出异常: $e');
      }
      return false;
    }
  }

  /// 批量导出离线视频
  static Future<void> exportBatch(
    List<BiliDownloadEntryInfo> items, {
    VoidCallback? onComplete,
  }) async {
    if (items.isEmpty) return;

    final exportDir = await getExportDirectory();
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final currentTitle = item.title.isNotEmpty ? item.title : item.showTitle;
      SmartDialog.showLoading(
        msg: '正在导出 (${i + 1}/${items.length})\n$currentTitle',
      );

      try {
        final (videoFile, audioFile) = resolveMediaFiles(item);
        if (!videoFile.existsSync()) {
          failCount++;
          continue;
        }

        final safeName = buildExportFileName(item);
        final outPath = await getUniqueOutputPath(exportDir, safeName);

        final ok = await muxOrCopy(
          videoFile: videoFile,
          audioFile: audioFile,
          outputPath: outPath,
        );

        if (ok) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    SmartDialog.dismiss();
    SmartDialog.showToast(
      '批量导出完成：成功 $successCount 个${failCount > 0 ? "，失败 $failCount 个" : ""}\n已保存至: $exportDir',
      displayTime: const Duration(seconds: 4),
    );

    onComplete?.call();
  }
}
