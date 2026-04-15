import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:openim_common/openim_common.dart';

import 'log_util.dart';

/// 下载管理器 - 防止重复下载
class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  // 当前下载状态
  bool _isDownloading = false;

  // 最后一次下载的URL
  String? _lastDownloadUrl;

  // 下载时间戳
  int? _lastDownloadTimestamp;

  // 开始下载
  Future<bool> startDownload(String url) async {
    LogUtil.i('DownloadManager', '尝试下载URL: $url');

    // 检查是否已经在下载
    if (_isDownloading) {
      LogUtil.w('DownloadManager', '已有下载任务正在进行中，跳过');
      return false;
    }

    // 检查是否是相同URL的重复下载(5分钟内)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastDownloadUrl == url &&
        _lastDownloadTimestamp != null &&
        (now - _lastDownloadTimestamp!) < 5 * 60 * 1000) {
      LogUtil.w('DownloadManager', '5分钟内已下载相同URL，跳过');
      return false;
    }

    // 更新状态
    _isDownloading = true;
    _lastDownloadUrl = url;
    _lastDownloadTimestamp = now;

    // 给URL添加唯一参数，防止浏览器缓存
    final uniqueUrl = _addUniqueParameters(url);
    LogUtil.i('DownloadManager', '添加唯一参数后的URL: $uniqueUrl');

    try {
      // 执行下载
      final result = await launchUrlString(
        uniqueUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!result) {
        LogUtil.e('DownloadManager', '无法打开URL: $uniqueUrl');
        IMViews.showToast('打开下载链接失败');
        _resetDownloadState();
        return false;
      }

      LogUtil.i('DownloadManager', '已启动下载: $uniqueUrl');
      return true;
    } catch (e) {
      LogUtil.e('DownloadManager', '下载启动失败: $e');
      IMViews.showToast('启动下载失败: $e');
      // 重置状态
      _resetDownloadState();
      return false;
    } finally {
      // 延时重置下载状态(30秒后)
      Future.delayed(const Duration(seconds: 30), _resetDownloadState);
    }
  }

  // 添加唯一参数到URL，防止浏览器缓存
  // 2026-03-28（预签名 URL 不可改 query，否则会签名校验失败）
  String _addUniqueParameters(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      if (_isPresignedUrl(uri)) {
        LogUtil.i('DownloadManager', '检测到预签名下载链接，跳过追加 _t');
        return baseUrl;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = Map<String, dynamic>.from(uri.queryParameters);
      params['_t'] = '$timestamp';

      final newUri = uri.replace(queryParameters: params);
      return newUri.toString();
    } catch (e) {
      LogUtil.e('DownloadManager', '添加URL参数失败: $e');
      return baseUrl;
    }
  }

  /// 是否为对象存储等服务的预签名 URL（追加任意 query 会破坏签名）
  static bool _isPresignedUrl(Uri uri) {
    final keys = uri.queryParameters.keys.map((k) => k.toLowerCase()).toSet();
    if (keys.isEmpty) return false;

    // AWS S3 / MinIO 等
    if (keys.contains('x-amz-signature') ||
        keys.contains('x-amz-credential') ||
        keys.contains('x-amz-algorithm')) {
      return true;
    }
    // 旧版 S3
    if (keys.contains('awsaccesskeyid') && keys.contains('signature')) {
      return true;
    }
    // Google Cloud Storage
    if (keys.contains('x-goog-signature') ||
        keys.contains('x-goog-credential') ||
        keys.contains('x-goog-algorithm')) {
      return true;
    }
    // 阿里云 OSS 等（Query 中含 Signature）
    if (keys.contains('signature') ||
        keys.contains('ossaccesskeyid')) {
      return true;
    }
    // Azure Blob SAS
    if (keys.contains('sig') && (keys.contains('sv') || keys.contains('se'))) {
      return true;
    }
    return false;
  }

  // 重置下载状态
  void _resetDownloadState() {
    LogUtil.i('DownloadManager', '重置下载状态');
    _isDownloading = false;
  }

  // 检查是否已在下载
  bool get isDownloading => _isDownloading;

  // 清除下载状态(手动)
  void clearDownloadState() {
    _isDownloading = false;
    LogUtil.i('DownloadManager', '手动清除下载状态');
  }
}