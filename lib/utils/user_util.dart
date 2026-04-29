import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/core/security_service.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/pages/conversation/conversation_logic.dart';
import 'package:openim/pages/home/home_logic.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim/utils/app_log_uploader.dart';
import 'package:openim/utils/luck_money_status_manager.dart';

class UserUtil {
  /// 用户登出
  static Future<void> logout() {
    return LoadingView.singleton.wrap(asyncFunction: () async {
      final securityService = SecurityService();
      final imLogic = Get.find<IMController>();
      final orgController = Get.find<OrgController>();

      await AppLogUploader.instance
          .flush(reason: 'logout')
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      // 清除RSA相关数据
      await securityService.clearSecurityData();

      // 清理所有红包状态
      await LuckMoneyStatusManager.clearAllLuckMoneyStatuses();

      // 执行原有的登出逻辑
      await imLogic.logout();
      await DataSp.removeLoginCertificate();
      orgController.resetOrg();
      PushController.logout();
      Get.delete<WalletController>(force: true);
      Get.find<HomeLogic>().conversationsAtFirstPage.clear();

      AppNavigator.startLogin();
    });
  }

  static Future<void> changeOrg(String organizationId) async {
    final orgController = Get.find<OrgController>();
    final imLogic = Get.find<IMController>();

    if (organizationId == orgController.currentOrgId.value) return;
    LoadingView.singleton.wrap(asyncFunction: () async {
      DataSp.putOrgId(organizationId);
      final changeOrgData = await Apis.changeOrgUser(organizationId);
      var data = DataSp.getLoginCertificate()!;
      data.imToken = changeOrgData.imToken!;
      data.userID = changeOrgData.imServerUserId!;
      await imLogic.logout();
      PushController.logout();

      DataSp.putLoginCertificate(data);
      await imLogic.login(data.userID, data.imToken);

      PushController.login(
        data.userID,
        onTokenRefresh: (token) {
          OpenIM.iMManager.updateFcmToken(
              fcmToken: token,
              expireTime: DateTime.now()
                  .add(const Duration(days: 90))
                  .millisecondsSinceEpoch);
        },
      );

      final result = await ConversationLogic.getConversationFirstPage();
      Get.find<HomeLogic>().conversationsAtFirstPage = result;
      Get.find<ConversationLogic>().getFirstPage();
      orgController.currentOrgId.value = organizationId;
      Get.find<WalletController>().reinitialize();
    });
  }
}
