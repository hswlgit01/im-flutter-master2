import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../utils/log_util.dart';
import '../utils/version_utils.dart';
import '../utils/download_manager.dart';

/// APK更新管理器 - 处理应用级别更新
///
/// 功能：
/// 1. 检查服务器上的APK版本与当前版本
/// 2. 当发现新版本时显示更新对话框
/// 3. 引导用户下载和安装新版本
class ApkUpdateManager {
  static final ApkUpdateManager _instance = ApkUpdateManager._internal();
  factory ApkUpdateManager() => _instance;
  ApkUpdateManager._internal();

  // 使用下载管理器
  final DownloadManager _downloadManager = DownloadManager();

  // 缓存当前版本信息
  String? _currentVersion;
  PackageInfo? _packageInfo;

  // 获取当前应用版本
  Future<String> getCurrentVersion() async {
    if (_currentVersion != null) return _currentVersion!;

    try {
      _packageInfo ??= await PackageInfo.fromPlatform();
      _currentVersion = _packageInfo!.version;
      return _currentVersion!;
    } catch (e) {
      LogUtil.e('ApkUpdate', '获取当前版本失败', e);
      return '0.0.0'; // 获取失败时返回默认版本
    }
  }

  /// 检查APK版本更新
  ///
  /// 参数:
  /// - showNoUpdateToast: 当无更新时是否显示提示
  /// - showUpdateDialog: 发现新版本时是否显示对话框
  ///
  /// 返回:
  /// - true: 有新版本可用
  /// - false: 无新版本或检查失败
  Future<bool> checkApkUpdate({
    bool showNoUpdateToast = false,
    bool showUpdateDialog = true,
  }) async {
    try {
      LogUtil.i('ApkUpdate', '开始检查APK主版本更新...');

      // 获取当前版本
      final currentVersion = await getCurrentVersion();
      LogUtil.i('ApkUpdate', '当前版本: $currentVersion');

      // 仅在Android平台执行
      if (!Platform.isAndroid) {
        LogUtil.i('ApkUpdate', '非Android平台，跳过APK检查');
        return false;
      }

      // 获取远程配置
      final remoteConfig = DataSp.getRemoteConfig();
      LogUtil.i('ApkUpdate', '远程配置: ${remoteConfig != null ? '可用' : '为空'}');
      if (remoteConfig != null) {
        LogUtil.i('ApkUpdate', '远程配置键值: ${remoteConfig.keys.toList().join(', ')}');
      }

      if (remoteConfig == null) {
        LogUtil.w('ApkUpdate', '无法获取远程配置');
        return false;
      }

      // 检查是否包含app_version字段
      if (!remoteConfig.containsKey('app_version')) {
        LogUtil.w('ApkUpdate', '远程配置中未包含app_version信息');
        LogUtil.i('ApkUpdate', '远程配置完整内容: $remoteConfig');
        return false;
      }

      // 提取Android版本信息
      final appVersionConfig = remoteConfig['app_version'];
      LogUtil.i('ApkUpdate', 'app_version配置: ${appVersionConfig != null ? '可用' : '为空'}');
      if (appVersionConfig != null) {
        LogUtil.i('ApkUpdate', 'app_version类型: ${appVersionConfig.runtimeType}');
        if (appVersionConfig is Map) {
          LogUtil.i('ApkUpdate', 'app_version键值: ${appVersionConfig.keys.toList().join(', ')}');
        }
      }

      if (appVersionConfig == null || !appVersionConfig.containsKey('android')) {
        LogUtil.w('ApkUpdate', '远程配置中未包含android版本信息');
        return false;
      }

      final androidConfig = appVersionConfig['android'];
      LogUtil.i('ApkUpdate', 'android配置: ${androidConfig != null ? '可用' : '为空'}');
      if (androidConfig != null) {
        LogUtil.i('ApkUpdate', 'android配置类型: ${androidConfig.runtimeType}');
        if (androidConfig is Map) {
          LogUtil.i('ApkUpdate', 'android配置键值: ${androidConfig.keys.toList().join(', ')}');
        }
      }

      final serverVersion = androidConfig?['version'];
      final downloadUrl = androidConfig?['download_url'];
      final releaseNotes = androidConfig?['release_notes'] ?? '新版本已发布';
      final forceUpdate = androidConfig?['force_update'] ?? false;

      LogUtil.i('ApkUpdate', '提取的版本信息: version=$serverVersion, url=$downloadUrl');

      if (serverVersion == null || downloadUrl == null) {
        LogUtil.w('ApkUpdate', '远程配置中缺少version或download_url字段');
        return false;
      }

      LogUtil.i('ApkUpdate', '服务器版本: $serverVersion, 下载地址: $downloadUrl');

      // 比较版本
      final int compareResult = VersionUtils.compareVersions(
        serverVersion,
        currentVersion,
      );

      if (compareResult <= 0) {
        // 服务器版本 <= 当前版本，无需更新
        LogUtil.i('ApkUpdate', '当前已是最新版本，无需更新');
        if (showNoUpdateToast) {
          IMViews.showToast('已是最新版本');
        }
        return false;
      }

      // 有新版本可用
      LogUtil.i('ApkUpdate', '发现新版本: $serverVersion，当前版本: $currentVersion');

      // 显示更新对话框
      if (showUpdateDialog) {
        _showUpdateDialog(
          serverVersion: serverVersion,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          forceUpdate: forceUpdate,
        );
      }

      return true;
    } catch (e, stack) {
      LogUtil.e('ApkUpdate', '检查APK更新失败', e, stack);
      return false;
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog({
    required String serverVersion,
    required String currentVersion,
    required String downloadUrl,
    required String releaseNotes,
    required bool forceUpdate,
  }) {
    Get.dialog(
      WillPopScope(
        onWillPop: () async => !forceUpdate, // 强制更新时不允许返回
        child: AlertDialog(
          title: Text(forceUpdate ? '需要更新' : '发现新版本'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前版本: $currentVersion'),
                Text('最新版本: $serverVersion'),
                const SizedBox(height: 16),
                const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(releaseNotes),
              ],
            ),
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                child: const Text('稍后更新'),
                onPressed: () {
                  LogUtil.i('ApkUpdate', '用户选择稍后更新');
                  Get.back();
                },
              ),
            TextButton(
              child: const Text('立即更新'),
              onPressed: () {
                LogUtil.i('ApkUpdate', '用户选择立即更新，下载地址: $downloadUrl');
                _launchDownload(downloadUrl);
                if (!forceUpdate) {
                  Get.back();
                }
              },
            ),
          ],
        ),
      ),
      barrierDismissible: !forceUpdate, // 强制更新时不允许点击外部关闭
    );
  }

  /// 启动下载 - 使用下载管理器防止重复下载
  Future<void> _launchDownload(String url) async {
    LogUtil.i('ApkUpdate', '准备下载APK，地址: $url');

    // 使用下载管理器安全启动下载
    final result = await _downloadManager.startDownload(url);

    if (!result) {
      LogUtil.w('ApkUpdate', '下载未开始，可能是已在进行中或近期已下载相同APK');
      IMViews.showToast('下载已在进行中或刚刚完成');
    }
  }
}