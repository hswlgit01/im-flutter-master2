import 'dart:io';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/team_info.dart';

class MyTeamLogic extends GetxController {
  final IMController imLogic = Get.find<IMController>();
  final RxBool isLoading = true.obs;
  final RxString downloadUrl = ''.obs;

  // 团队数据
  final Rx<TeamInfo?> teamInfo = Rx<TeamInfo?>(null);

  @override
  void onInit() {
    super.onInit();
    initializeData();
  }

  /// 初始化所有数据
  Future<void> initializeData() async {
    try {
      // 刷新远程配置以确保获取最新信息
      await refreshRemoteConfig();

      // 获取团队信息
      await refreshUserInfo();

      // 获取下载链接
      await getDownloadUrl();
    } catch (e) {
      print('初始化数据失败: $e');
    }
  }

  /// 刷新远程配置
  Future<void> refreshRemoteConfig() async {
    try {
      // 使用Config中的manualAutoRoute方法刷新远程配置
      await Config.manualAutoRoute();
      print('远程配置刷新完成');
    } catch (e) {
      print('刷新远程配置失败: $e');
    }
  }

  // 刷新用户信息（包含团队数据）
  Future<void> refreshUserInfo() async {
    try {
      isLoading.value = true;

      // 获取团队信息 - 使用新的客户端API
      final teamInfoData = await Apis.getUserTeamInfo();

      // 如果成功获取团队信息，更新本地状态
      if (teamInfoData != null) {
        teamInfo.value = teamInfoData;
        print('从团队API获取的数据: teamSize=${teamInfoData.teamSize}, directDownlineCount=${teamInfoData.directDownlineCount}, invitationCode=${teamInfoData.invitationCode}');
      } else {
        // 如果获取失败，使用空数据
        teamInfo.value = TeamInfo(
          userId: imLogic.userInfo.value?.userID ?? '',
          teamSize: 0,
          directDownlineCount: 0,
          invitationCode: '',
        );
      }
    } catch (e) {
      IMViews.showToast('获取用户信息失败');
      print('获取用户信息失败: $e');

      // 错误情况下也设置空数据
      teamInfo.value = TeamInfo(
        userId: imLogic.userInfo.value?.userID ?? '',
        teamSize: 0,
        directDownlineCount: 0,
        invitationCode: '',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 获取下载链接
  ///
  /// 从远程配置中获取下载链接，与APK更新系统使用相同的链接源
  /// 当远程配置不可用时，保持链接为空
  Future<void> getDownloadUrl() async {
    try {
      print('开始获取应用下载链接...');

      // 初始化为空
      downloadUrl.value = '';

      // 从远程配置中获取下载链接 - 与APK更新系统使用相同的数据源
      final remoteConfig = DataSp.getRemoteConfig();
      if (remoteConfig != null &&
          remoteConfig.containsKey('app_version') &&
          remoteConfig['app_version'] is Map) {

        final appVersionConfig = remoteConfig['app_version'];
        print('成功获取app_version配置: ${appVersionConfig.keys}');

        // 根据平台获取对应的下载链接
        if (Platform.isAndroid && appVersionConfig.containsKey('android')) {
          final androidConfig = appVersionConfig['android'];
          final downloadLink = androidConfig?['download_url'];

          if (downloadLink != null && downloadLink.isNotEmpty) {
            downloadUrl.value = downloadLink;
            print('从远程配置获取的Android下载链接: $downloadLink');
            return;
          }
        } else if (Platform.isIOS && appVersionConfig.containsKey('ios')) {
          final iosConfig = appVersionConfig['ios'];
          final downloadLink = iosConfig?['download_url'];

          if (downloadLink != null && downloadLink.isNotEmpty) {
            downloadUrl.value = downloadLink;
            print('从远程配置获取的iOS下载链接: $downloadLink');
            return;
          }
        }
      }

      final fallbackLink = _firstNonEmptyDownloadUrl(remoteConfig);
      if (fallbackLink != null) {
        downloadUrl.value = fallbackLink;
        print('从远程配置获取的通用下载链接: $fallbackLink');
        return;
      }

      // 如果无法从远程配置获取，链接保持为空
      print('未找到远程配置下载链接，链接为空');
    } catch (e) {
      // 异常情况下链接保持为空
      print('获取下载链接异常: $e，链接为空');
    }
  }

  String? _firstNonEmptyDownloadUrl(Map<String, dynamic>? remoteConfig) {
    final appVersionConfig = remoteConfig?['app_version'];
    if (appVersionConfig is! Map) return null;
    for (final value in appVersionConfig.values) {
      if (value is Map) {
        final link = value['download_url'];
        if (link is String && link.isNotEmpty) {
          return link;
        }
      }
    }
    return null;
  }

  // 复制邀请码
  void copyInvitationCode() {
    // 只使用 TeamInfo 中的邀请码
    final code = teamInfo.value?.invitationCode ?? '';
    if (code.isNotEmpty) {
      IMUtils.copy(text: code);
      IMViews.showToast('已复制邀请码');
    } else {
      IMViews.showToast('邀请码为空');
    }
  }

  // 复制下载链接
  void copyDownloadUrl() {
    if (downloadUrl.value.isNotEmpty) {
      IMUtils.copy(text: downloadUrl.value);
      IMViews.showToast('已复制下载链接');
    } else {
      IMViews.showToast('下载链接不可用，请等待配置');
      // 尝试重新获取
      refreshRemoteConfig().then((_) => getDownloadUrl());
    }
  }
}
