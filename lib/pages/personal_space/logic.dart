import 'dart:async';

import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/routes/app_pages.dart';
import 'package:openim/utils/log_util.dart';
import 'package:openim/utils/user_util.dart';
import 'package:openim_common/openim_common.dart';
import '../../core/controller/im_controller.dart';
import '../../routes/app_navigator.dart';

class PersonalSpaceLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final orgController = Get.find<OrgController>();
  static const String TAG = "MineLogic";
  late StreamSubscription kickedOfflineSub;

  void onViewOpened() {
    orgController.refreshOrgList();
  }

  void viewWallet() {
    Get.toNamed(AppRoutes.wallet);
  }

  void viewMyInfo() => AppNavigator.startMyInfo();

  void accountSetup() => AppNavigator.startAccountSetup();
  void aboutUs() => AppNavigator.startAboutUs();

  toQrCodePage() {
    AppNavigator.startMyQrcode();
  }

  void copyID() {
    IMUtils.copy(text: imLogic.userInfo.value.userID!);
  }

  void logout() async {
    var confirm = await Get.dialog(CustomDialog(title: StrRes.logoutHint));
    if (confirm == true) {
      try {
        UserUtil.logout();
      } catch (e) {
        LogUtil.e(TAG, '登出失败: $e');
        IMViews.showToast('e:$e');
      }
    }
  }

  addAcount() async {
    AppNavigator.startAddAcountPage();
  }

  changeOrg(String organizationId) async {
    if (organizationId == orgController.currentOrgId.value) return;
    await UserUtil.changeOrg(organizationId);
    Get.back();
  }
}
