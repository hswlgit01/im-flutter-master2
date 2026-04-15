import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:extended_image/extended_image.dart';
import 'package:openim_common/openim_common.dart';

/// 简化版头像更新工具 - 统一处理头像更新和缓存刷新
class AvatarUtil {
  /// 上传头像并更新用户信息
  static Future<bool> uploadAndUpdateAvatar({
    required String imagePath,
    required Function(bool success, String? newUrl) onComplete,
  }) async {
    try {
      // 1. 上传图片
      final uploadResult = await LoadingView.singleton.wrap(
        asyncFunction: () async {
          final compressedImage = await IMUtils.compressImageAndGetFile(
            File(imagePath),
            quality: 50, // 提高质量到50%
          );

          return await OpenIM.iMManager.uploadFile(
            id: "avatar_${DateTime.now().millisecondsSinceEpoch}",
            filePath: compressedImage?.path ?? imagePath,
            fileName: "avatar_${DateTime.now().millisecondsSinceEpoch}.jpg",
          );
        },
      );

      // 解析获取URL
      final parsedResult = uploadResult is String ? jsonDecode(uploadResult) : null;
      final String? url = parsedResult?['url'];

      if (url == null) {
        onComplete(false, null);
        return false;
      }

      // 2. 创建带随机参数的URL (核心技巧：强制绕开缓存)
      final refreshedURL = await _createRefreshedURL(url);

      // 3. 双重更新：API和SDK
      // 先更新API服务器
      await Apis.updateUserInfo(
        userID: OpenIM.iMManager.userID,
        faceURL: refreshedURL,
      );

      // 再更新SDK (这是关键步骤，原代码缺少)
      await OpenIM.iMManager.userManager.setSelfInfo(
        faceURL: refreshedURL,
      );

      // 4. 清除所有缓存
      _clearAllCaches(url);
      _clearAllCaches(refreshedURL);
      _clearAllCaches(UrlConverter.convertMediaUrl(url));

      // 清除全局图像缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      onComplete(true, refreshedURL);
      return true;
    } catch (e) {
      onComplete(false, null);
      return false;
    }
  }

  /// 创建带随机参数的URL (强制绕开缓存的关键技术)
  static Future<String> _createRefreshedURL(String originalURL) async {
    // 确保URL是完整的
    String fullURL = originalURL;
    if (!originalURL.contains('://')) {
      fullURL = UrlConverter.convertMediaUrl(originalURL);
    }

    // 添加随机参数
    final random = Random().nextInt(10000000);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (fullURL.contains('?')) {
      return '$fullURL&_refresh=${timestamp}_$random';
    } else {
      return '$fullURL?_refresh=${timestamp}_$random';
    }
  }

  /// 清除URL缓存
  static void _clearAllCaches(String url) {
    // 清除内存缓存
    clearMemoryImageCache(keyToMd5(url));

    // 清除磁盘缓存
    clearDiskCachedImage(url);

    // 清除Flutter默认缓存
    PaintingBinding.instance.imageCache.evict(keyToMd5(url));
  }

  /// 公开的缓存清理方法
  static void clearCache(String url) {
    if (url.isEmpty) return;

    _clearAllCaches(url);

    // 同时清理URL转换后的缓存
    final convertedUrl = UrlConverter.convertMediaUrl(url);
    if (convertedUrl != url) {
      _clearAllCaches(convertedUrl);
    }
  }
}