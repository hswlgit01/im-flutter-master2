import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../../../core/controller/app_controller.dart';
import '../../../utils/log_util.dart';
import '../../../utils/hot_update_manager.dart';
import '../../../utils/apk_update_manager.dart';
import '../../../utils/update_service.dart';

class AboutUsLogic extends GetxController {
  final appLogic = Get.find<AppController>();
  final displayVersion = ''.obs;
  final shorebirdUpdater = ShorebirdUpdater();
  final _updateService = UpdateService(); // 使用统一的更新服务

  void getPackageInfo() async {
    LogUtil.i('Shorebird', '开始获取应用版本信息');

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final appName = packageInfo.appName;
    final buildNumber = packageInfo.buildNumber;

    LogUtil.i('Shorebird', '应用信息: name=$appName, version=$version, build=$buildNumber');

    // 获取 Shorebird 补丁号
    String patchInfo = '';
    try {
      LogUtil.i('Shorebird', '检查 Shorebird 可用性');
      final isShorebirdAvailable = await shorebirdUpdater.isAvailable;
      LogUtil.i('Shorebird', 'Shorebird 可用: $isShorebirdAvailable');

      if (isShorebirdAvailable) {
        final currentPatch = await shorebirdUpdater.readCurrentPatch();
        if (currentPatch != null && currentPatch.number != null) {
          patchInfo = ' (Patch ${currentPatch.number})';
          LogUtil.i('Shorebird', '当前补丁号: ${currentPatch.number}');
        } else {
          LogUtil.i('Shorebird', '当前无补丁或补丁信息为空');
        }
      }
    } catch (e) {
      LogUtil.e('Shorebird', '获取 Shorebird 补丁信息失败', e);
    }

    displayVersion.value = '$appName $version+$buildNumber$patchInfo SDK: ${OpenIM.version}';
    LogUtil.i('Shorebird', '完整版本信息: ${displayVersion.value}');
  }

  void checkUpdate() async {
    LogUtil.i('版本更新', '开始检查更新 - 使用统一的更新服务');

    // 使用统一的更新服务检查所有更新
    await _updateService.checkForUpdates(
      showNoUpdateToast: true,
      showUpdateDialog: true,
    );
  }

  // 这些方法不再需要，由统一的UpdateService处理

  void copyVersion() {
    LogUtil.i('Shorebird', '复制版本号: ${displayVersion.value}');
    IMViews.showToast(StrRes.copySuccessfully);
    Clipboard.setData(ClipboardData(text: displayVersion.value));
  }

  @override
  void onReady() {
    LogUtil.i('Shorebird', 'AboutUsLogic 初始化');
    getPackageInfo();
    super.onReady();
  }

  @override
  void onClose() {
    LogUtil.i('Shorebird', 'AboutUsLogic 销毁');
    super.onClose();
  }
}
