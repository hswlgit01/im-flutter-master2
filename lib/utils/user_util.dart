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
import 'package:openim/utils/log_util.dart';
import 'package:openim/utils/luck_money_status_manager.dart';

class UserUtil {
  /// 用户登出
  ///
  /// dawn 2026-07-07 修复"点退出登录一直转圈"：原实现把每一步串行 await 且无任何容错，
  /// 只要有一步卡住(尤其大群下 SDK `imLogic.logout()` 仍在增量同步会长时间阻塞)，整个流程
  /// 就永不返回，LoadingView 也永不消失。现改为：每一步单独 try/catch + 超时，SDK 登出加时限，
  /// 无论前面哪步失败/超时，最终都一定执行"清凭据 + 回登录页"，保证退出一定完成。
  static Future<void> logout() {
    return LoadingView.singleton.wrap(asyncFunction: () async {
      final securityService = SecurityService();
      final orgController = Get.find<OrgController>();

      try {
        await AppLogUploader.instance
            .flush(reason: 'logout')
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
      } catch (_) {}

      // dawn 2026-07-07 关键：try/catch 只能兜异常，兜不住【卡死(await 永不返回)】。原实现里
      // clearSecurityData/clearAllLuckMoneyStatuses/removeLoginCertificate 都没有超时，任一步在
      // 异常设备上 SharedPreferences/原生通道卡住，整个退出仍会一直转圈。故【每一步都加超时】，
      // 保证 logout 总能在有限时间内推进到"清凭据 + 回登录页"。
      // 清除RSA相关数据
      try {
        await securityService
            .clearSecurityData()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        LogUtil.e('UserUtil', '清除安全数据失败/超时(继续登出): $e');
      }

      // 清理所有红包状态
      try {
        await LuckMoneyStatusManager.clearAllLuckMoneyStatuses()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}

      // 执行 SDK 登出：加超时兜底，避免大群同步期间原生 logout 阻塞卡死整个退出流程。
      try {
        final imLogic = Get.find<IMController>();
        await imLogic.logout().timeout(const Duration(seconds: 8));
      } catch (e) {
        LogUtil.e('UserUtil', 'SDK 登出超时/失败(继续回登录页): $e');
      }

      // 清登录凭据：这一步决定下次启动能否停在登录页(splash 据 userID/imToken 判断自动登录)，
      // 必须尽力完成；加超时并重试一次，避免卡死也避免漏清导致"退了又自动登回去"。
      try {
        await DataSp.removeLoginCertificate()
            ?.timeout(const Duration(seconds: 3));
      } catch (e) {
        LogUtil.e('UserUtil', '清登录凭据失败/超时，重试一次: $e');
        try {
          await DataSp.removeLoginCertificate()
              ?.timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      try {
        orgController.resetOrg();
      } catch (_) {}
      try {
        PushController.logout();
      } catch (_) {}
      try {
        Get.delete<WalletController>(force: true);
      } catch (_) {}
      try {
        Get.find<HomeLogic>().conversationsAtFirstPage.clear();
      } catch (_) {}

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
