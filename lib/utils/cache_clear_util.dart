import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:openim_common/openim_common.dart';

/// 清空缓存结果，用于日志和界面反馈
class ClearCacheResult {
  final int bytesCleared;
  final int itemsCleared;
  final bool imDataCleared;
  ClearCacheResult({this.bytesCleared = 0, this.itemsCleared = 0, this.imDataCleared = false});
  String get sizeText {
    if (bytesCleared <= 0) return '';
    if (bytesCleared < 1024) return '${bytesCleared}B';
    if (bytesCleared < 1024 * 1024) return '${(bytesCleared / 1024).toStringAsFixed(1)}KB';
    return '${(bytesCleared / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// 应用内清空缓存工具。
/// 用于解决 WebSocket 因「消息过大 / read limit exceeded」等导致的反复断连；可与安卓「清除数据」达到类似效果（保留登录态）。
class CacheClearUtil {
  /// 清空应用缓存。
  /// [includeImDataDir] 为 true 时，会同时清空 OpenIM 本地数据库目录（Config.cachePath），
  /// 达到与系统「清除数据」类似的效果，可彻底缓解 read limit exceeded；清空后建议重启应用。
  /// 不删 SharedPreferences（登录态保留）。
  static Future<ClearCacheResult> clearAppCache({bool includeImDataDir = false}) async {
    debugPrint('[CacheClearUtil] clearAppCache 开始, includeImDataDir=$includeImDataDir');
    int totalBytes = 0;
    int totalItems = 0;
    bool imDataCleared = false;

    // 1. 清空系统临时目录
    try {
      final tempDir = await getTemporaryDirectory();
      debugPrint('[CacheClearUtil] 临时目录: ${tempDir.path}');
      if (tempDir.existsSync()) {
        final res = _deleteDirectoryContents(tempDir);
        totalBytes += res.bytes;
        totalItems += res.items;
        debugPrint('[CacheClearUtil] 临时目录已清空: ${res.items} 项, ${res.bytes} 字节');
      }
    } catch (e, st) {
      debugPrint('[CacheClearUtil] 清空临时目录异常: $e\n$st');
    }

    // 2. 清空应用缓存目录（图片、下载等缓存常在此）
    try {
      final cacheDir = await getApplicationCacheDirectory();
      debugPrint('[CacheClearUtil] 应用缓存目录: ${cacheDir.path}');
      if (cacheDir.existsSync()) {
        final res = _deleteDirectoryContents(cacheDir);
        totalBytes += res.bytes;
        totalItems += res.items;
        debugPrint('[CacheClearUtil] 应用缓存目录已清空: ${res.items} 项, ${res.bytes} 字节');
      }
    } catch (e, st) {
      debugPrint('[CacheClearUtil] 清空应用缓存目录异常: $e\n$st');
    }

    // 3. 可选：清空 IM 数据目录（OpenIM 数据库、日志等），与安卓「清除数据」对 read limit exceeded 的效果一致
    if (includeImDataDir) {
      try {
        final imDir = Directory(Config.cachePath);
        debugPrint('[CacheClearUtil] IM 数据目录: ${imDir.path}');
        if (imDir.existsSync()) {
          final res = _deleteDirectoryContents(imDir);
          totalBytes += res.bytes;
          totalItems += res.items;
          imDataCleared = true;
          debugPrint('[CacheClearUtil] IM 数据目录已清空: ${res.items} 项, ${res.bytes} 字节');
        }
      } catch (e, st) {
        debugPrint('[CacheClearUtil] 清空 IM 数据目录异常: $e\n$st');
      }
    }

    // 4. 清空 Flutter 图片内存缓存
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('[CacheClearUtil] 图片内存缓存已清空');
    } catch (e) {
      debugPrint('[CacheClearUtil] 清空图片缓存异常: $e');
    }

    final result = ClearCacheResult(bytesCleared: totalBytes, itemsCleared: totalItems, imDataCleared: imDataCleared);
    debugPrint('[CacheClearUtil] clearAppCache 完成: 共 ${result.itemsCleared} 项, ${result.sizeText}, imDataCleared=$imDataCleared');
    return result;
  }

  static ({int bytes, int items}) _deleteDirectoryContents(Directory dir) {
    int bytes = 0;
    int items = 0;
    for (final entity in dir.listSync(followLinks: false)) {
      try {
        if (entity is Directory) {
          final res = _dirSize(entity);
          entity.deleteSync(recursive: true);
          bytes += res.bytes;
          items += res.items;
        } else if (entity is File) {
          bytes += entity.lengthSync();
          items += 1;
          entity.deleteSync();
        }
      } catch (e) {
        debugPrint('[CacheClearUtil] 删除失败 ${entity.path}: $e');
      }
    }
    return (bytes: bytes, items: items);
  }

  static ({int bytes, int items}) _dirSize(Directory dir) {
    int bytes = 0;
    int items = 0;
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File) {
          bytes += entity.lengthSync();
          items += 1;
        } else if (entity is Directory) {
          final sub = _dirSize(entity);
          bytes += sub.bytes;
          items += sub.items;
        }
      }
    } catch (_) {}
    return (bytes: bytes, items: items);
  }
}
