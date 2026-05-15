import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim/pages/login/login_logic.dart';
import 'package:openim/pages/mine/edit_my_info/edit_my_info_logic.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim/utils/avatar_util.dart';
import 'package:openim_common/openim_common.dart';
import '../../../core/controller/im_controller.dart';
import 'identity_verify/identity_verify_view.dart';

class MyInfoLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final loginType = LoginType.fromRawValue(DataSp.getLoginType());
  final orgController = Get.find<OrgController>();
  final userInfo = Rx<UserFullInfo?>(null);

  // 身份认证数据
  final Rx<IdentityVerifyInfo?> _identityInfo = Rx<IdentityVerifyInfo?>(null);

  // 获取身份信息
  IdentityVerifyInfo? get identityInfo {
    return _identityInfo.value;
  }

  void editMyName() {
    // dawn 2026-05-15 修复旧 basic 用户无法改昵称：昵称权限统一走兼容判断。
    if (orgController.canModifyNickname) {
      AppNavigator.startEditMyInfo();
    }
  }

  void editEnglishName() => AppNavigator.startEditMyInfo(
        attr: EditAttr.englishName,
      );

  void editTel() => AppNavigator.startEditMyInfo(
        attr: EditAttr.telephone,
      );

  void editMobile() => AppNavigator.startEditMyInfo(
        attr: EditAttr.mobile,
      );

  void editEmail() =>
      AppNavigator.startEditMyInfo(attr: EditAttr.email, maxLength: 30);

  void openPhotoSheet() {
    IMViews.openPhotoSheet(
        onData: (path, url) async {
          if (path != null) {
            // 显示加载对话框
            LoadingView.singleton.show();

            // 使用简化版的AvatarUtil处理整个流程
            await AvatarUtil.uploadAndUpdateAvatar(
              imagePath: path,
              onComplete: (success, newUrl) async {
                if (success && newUrl != null) {
                  // 1. 更新本地显示（UI层）
                  imLogic.userInfo.update((val) {
                    val?.faceURL = newUrl;
                  });
                  userInfo.refresh();

                  // 2. 关闭加载对话框
                  LoadingView.singleton.dismiss();

                  // 3. 通知用户
                  IMViews.showToast("头像更新成功");

                  // 4. 强制刷新页面
                  update();

                  // 5. 延迟二次刷新确保UI完全更新
                  Future.delayed(Duration(milliseconds: 500), () {
                    update();
                    Get.forceAppUpdate();
                  });
                } else {
                  LoadingView.singleton.dismiss();
                  IMViews.showToast("头像更新失败");
                }
              },
            );
          }
        },
        quality: 50);
  }

  void openDatePicker() {
    var appLocale = Get.locale;
    var isZh = appLocale!.languageCode.toLowerCase().contains("zh");
    DatePicker.showDatePicker(
      Get.context!,
      locale: isZh ? LocaleType.zh : LocaleType.en,
      minTime: DateTime(1900, 1, 1), // 添加最小时间限制为1900年1月1日
      maxTime: DateTime.now(),
      currentTime: DateTime.fromMillisecondsSinceEpoch(
          imLogic.userInfo.value.birth ?? 0),
      theme: DatePickerTheme(
        cancelStyle: Styles.ts_0C1C33_17sp,
        doneStyle: Styles.ts_0089FF_17sp,
        itemStyle: Styles.ts_0C1C33_17sp,
      ),
      onConfirm: (dateTime) {
        _updateBirthday(dateTime.millisecondsSinceEpoch ~/ 1000);
      },
    );
  }

  void selectGender() {
    Get.bottomSheet(
      BottomSheetView(
        items: [
          SheetItem(
            label: StrRes.man,
            onTap: () => _updateGender(1),
          ),
          SheetItem(
            label: StrRes.woman,
            onTap: () => _updateGender(2),
          ),
        ],
      ),
    );
  }

  void _updateGender(int gender) {
    LoadingView.singleton.wrap(
      asyncFunction: () =>
          Apis.updateUserInfo(userID: OpenIM.iMManager.userID, gender: gender)
              .then((value) => imLogic.userInfo.update((val) {
                    val?.gender = gender;
                  })),
    );
  }

  void _updateBirthday(int birthday) {
    LoadingView.singleton.wrap(
      asyncFunction: () => Apis.updateUserInfo(
        userID: OpenIM.iMManager.userID,
        birth: birthday * 1000,
      ).then((value) => imLogic.userInfo.update((val) {
            val?.birth = birthday * 1000;
          })),
    );
  }

  /// 强制刷新用户信息和缓存
  Future<void> forceRefreshUserInfo() async {
    try {
      // 获取当前用户头像
      final faceURL = imLogic.userInfo.value.faceURL;
      if (faceURL != null && faceURL.isNotEmpty) {
        // 获取自己的用户信息（从SDK）
        final selfInfo = await OpenIM.iMManager.userManager.getSelfUserInfo();

        // 获取完整用户信息（从API）
        final user = await Apis.getUserFullInfo(
            pageNumber: 1,
            showNumber: 1,
            userIDList: [selfInfo.userID ?? OpenIM.iMManager.userID]);

        if (user != null && user.isNotEmpty) {
          // 更新本地用户信息和全局用户信息
          userInfo.value = user.first;
          userInfo.refresh();

          // 同时更新SDK中的用户信息
          await OpenIM.iMManager.userManager.setSelfInfo(
            faceURL: user.first.faceURL,
          );

          // 清除头像URL的缓存
          if (user.first.faceURL != null && user.first.faceURL!.isNotEmpty) {
            AvatarUtil.clearCache(user.first.faceURL!);
          }

          // 强制刷新
          imLogic.userInfo.refresh();
          update();
        }
      }
    } catch (e) {
      Logger.print("强制刷新用户信息失败: $e");
    }
  }

  @override
  void onReady() {
    getUserInfo();

    // 页面加载完成后，延迟强制刷新一次用户信息
    Future.delayed(const Duration(milliseconds: 500), () {
      forceRefreshUserInfo();
    });

    // 页面重新获取焦点时也强制刷新
    Future.delayed(const Duration(seconds: 2), () {
      forceRefreshUserInfo();
    });

    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
  }

  static _trimNullStr(String? value) => IMUtils.emptyStrToNull(value);

  void copyAccount() {
    IMUtils.copy(text: userInfo.value?.account ?? '');
  }

  copyInvitationCode() {
    IMUtils.copy(text: userInfo.value?.invitationCode ?? '');
  }

  void getUserInfo() async {
    final user = await Apis.getUserFullInfo(
        pageNumber: 1,
        showNumber: 1,
        userIDList: [imLogic.userInfo.value.userID!]);
    if (user != null) {
      userInfo.value = user.firstOrNull;
    }

    // 获取身份认证信息
    await getIdentityInfo();
  }

  // 获取身份认证信息
  Future<void> getIdentityInfo() async {
    try {
      final info = await Apis.getIdentityInfo();
      _identityInfo.value = info;
    } catch (e) {
      ILogger.e('获取身份认证信息失败', e);
      // 失败时设置为待认证状态
      _identityInfo.value = IdentityVerifyInfo(status: 0);
    }
  }

  void openIdentityVerifyPage() {
    final currentInfo = identityInfo;

    // 直接使用 Get.to
    Get.to(
      () => IdentityVerifyPage(initialInfo: currentInfo),
    )?.then((result) {
      if (result != null && result is IdentityVerifyInfo) {
        // 更新本地状态
        _identityInfo.value = result;
        // 重新获取最新状态
        getIdentityInfo();
      }
    });
  }
}
