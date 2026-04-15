import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'apk_update_manager.dart';
import 'download_manager.dart';
import 'hot_update_manager.dart';
import 'log_util.dart';
import 'version_utils.dart';

/// 统一的更新服务
///
/// 提供集中的版本更新管理，避免重复检查和下载问题
/// 使用单例模式，确保全局只有一个更新实例
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // 子组件
  final ApkUpdateManager _apkUpdateManager = ApkUpdateManager();
  final HotUpdateManager _hotUpdateManager = HotUpdateManager();
  final DownloadManager _downloadManager = DownloadManager();

  // 状态标志
  bool _isCheckingUpdate = false;

  /// 检查应用更新
  ///
  /// 先检查APK主版本更新，如果没有再检查热更新
  /// 返回是否有更新可用
  Future<bool> checkForUpdates({
    bool showNoUpdateToast = true,
    bool showUpdateDialog = true,
  }) async {
    // 防止重复检查
    if (_isCheckingUpdate) {
      LogUtil.w('UpdateService', '更新检查已在进行中，跳过');
      return false;
    }

    _isCheckingUpdate = true;

    try {
      LogUtil.i('UpdateService', '开始检查更新 - 先刷新远程配置');

      // 首先刷新远程配置
      await _refreshRemoteConfig();

      // 等待配置刷新完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 检查APK更新
      LogUtil.i('UpdateService', '检查APK主版本更新');
      final hasApkUpdate = await _checkApkUpdateInternal(
        showNoUpdateToast: false, // 暂不显示toast，等待热更新检查完成
        showUpdateDialog: showUpdateDialog,
      );

      // 如果有APK更新，跳过热更新检查
      if (hasApkUpdate) {
        LogUtil.i('UpdateService', '发现APK主版本更新，跳过热更新检查');
        return true;
      }

      // 无APK更新，检查热更新
      LogUtil.i('UpdateService', '无APK主版本更新，继续检查热更新');
      final hasShorebirdUpdate = await _checkShorebirdUpdateInternal();

      // 如果都没有更新，显示提示
      if (!hasApkUpdate && !hasShorebirdUpdate && showNoUpdateToast) {
        IMViews.showToast('已是最新版本');
      }

      return hasApkUpdate || hasShorebirdUpdate;
    } catch (e, stackTrace) {
      LogUtil.e('UpdateService', '检查更新异常', e, stackTrace);
      return false;
    } finally {
      // 延迟重置状态
      Future.delayed(const Duration(seconds: 5), () {
        _isCheckingUpdate = false;
      });
    }
  }

  /// 刷新远程配置（使用无缓存请求）
  Future<void> _refreshRemoteConfig() async {
    LogUtil.i('UpdateService', '======== 开始刷新远程配置 ========');

    await Config.manualAutoRoute();

    LogUtil.i('UpdateService', '======== 远程配置刷新完成 ========');
  }

  /// 内部检查APK更新方法
  Future<bool> _checkApkUpdateInternal({
    required bool showNoUpdateToast,
    required bool showUpdateDialog,
  }) async {
    LogUtil.i('UpdateService', '======== 开始检查APK主版本更新 ========');

    try {
      // 使用Loading视图包装，但只调用一次APK检查
      bool hasUpdate = false;

      await LoadingView.singleton.wrap(asyncFunction: () async {
        hasUpdate = await _apkUpdateManager.checkApkUpdate(
          showNoUpdateToast: showNoUpdateToast,
          showUpdateDialog: showUpdateDialog,
        );
        return hasUpdate;
      });

      LogUtil.i('UpdateService', '======== APK主版本检查完成: hasUpdate=$hasUpdate ========');
      return hasUpdate;
    } catch (e, stackTrace) {
      LogUtil.e('UpdateService', '检查APK更新异常', e, stackTrace);
      return false;
    }
  }

  /// 内部检查热更新方法
  Future<bool> _checkShorebirdUpdateInternal() async {
    LogUtil.i('UpdateService', '======== 开始检查热更新 ========');

    try {
      // 获取当前版本信息
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = '${packageInfo.appName} ${packageInfo.version}+${packageInfo.buildNumber}';

      // 临时变量存储更新状态
      bool hasUpdate = false;

      await LoadingView.singleton.wrap(asyncFunction: () async {
        // 使用临时回调捕获结果
        await _hotUpdateManager.checkUpdateOnStartup(
          onUpdateAvailable: (version) {
            hasUpdate = true;

            // 显示更新对话框
            Get.dialog(
              AlertDialog(
                title: const Text('发现新版本'),
                content: Text(
                  '检测到新的热更新补丁可用\n\n'
                  '当前版本: $currentVersion\n'
                  '补丁将在后台下载,下载完成后重启应用即可生效',
                ),
                actions: [
                  TextButton(
                    child: const Text('稍后'),
                    onPressed: () {
                      LogUtil.i('UpdateService', '用户选择稍后更新');
                      Get.back();
                    },
                  ),
                  TextButton(
                    child: const Text('立即更新'),
                    onPressed: () async {
                      LogUtil.i('UpdateService', '用户选择立即更新');
                      Get.back();
                      await _downloadShorebirdUpdateInternal();
                    },
                  ),
                ],
              ),
            );
          },
        );
      });

      LogUtil.i('UpdateService', '======== 热更新检查完成: hasUpdate=$hasUpdate ========');
      return hasUpdate;
    } catch (e, stackTrace) {
      LogUtil.e('UpdateService', '检查热更新异常', e, stackTrace);
      return false;
    }
  }

  /// 下载热更新补丁
  Future<bool> _downloadShorebirdUpdateInternal() async {
    LogUtil.i('UpdateService', '======== 开始下载热更新补丁 ========');

    bool success = false;

    await LoadingView.singleton.wrap(asyncFunction: () async {
      try {
        success = await _hotUpdateManager.downloadUpdateWithProgress();

        if (success) {
          LogUtil.i('UpdateService', '补丁下载成功');

          // 提示重启
          Get.dialog(
            AlertDialog(
              title: const Text('更新完成'),
              content: const Text('补丁已下载完成,请重启应用以应用更新'),
              actions: [
                TextButton(
                  child: const Text('知道了'),
                  onPressed: () {
                    LogUtil.i('UpdateService', '用户确认下载完成提示');
                    Get.back();
                  },
                ),
              ],
            ),
          );
        } else {
          throw Exception('下载失败');
        }
      } catch (e) {
        LogUtil.e('UpdateService', '下载热更新补丁失败', e);
        IMViews.showToast('下载失败: $e');
        return false;
      }

      return success;
    });

    LogUtil.i('UpdateService', '======== 热更新补丁下载完成: success=$success ========');
    return success;
  }
}