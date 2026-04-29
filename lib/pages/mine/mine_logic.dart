import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:openim/core/im_callback.dart';
import 'package:openim_common/openim_common.dart';

import '../../core/controller/im_controller.dart';
import '../../core/security_service.dart';
import '../../utils/log_util.dart';
import '../../routes/app_navigator.dart';
import '../../routes/app_pages.dart';
import '../../utils/user_util.dart';
import 'my_info/identity_verify/identity_verify_view.dart';

class MineLogic extends GetxController with GetxServiceMixin {
  static const _tag = 'MineLogic';

  final imLogic = Get.find<IMController>();
  final _securityService = SecurityService();

  // 身份认证数据
  final Rx<IdentityVerifyInfo?> _identityInfo = Rx<IdentityVerifyInfo?>(null);

  // 最后一次刷新身份认证信息的时间
  int _lastRefreshTime = 0;

  // 获取身份信息
  IdentityVerifyInfo? get identityInfo {
    return _identityInfo.value;
  }

  late StreamSubscription kickedOfflineSub;

  void viewMyInfo() => AppNavigator.startMyInfo();

  void viewMyTeam() => AppNavigator.startMyTeam();

  void copyID() {
    IMUtils.copy(text: imLogic.userInfo.value.userID!);
  }

  void toSignIn() async {
    if (identityInfo?.status != 2) {
      final confirm = await Get.dialog(
        CustomDialog(
          title: StrRes.identityVerify,
          content: StrRes.verifyBeforeCheckin,
        ),
      );
      if (confirm == true) {
        openIdentityVerifyPage();
      }
      return;
    }
    AppNavigator.startCheckin();
  }

  void viewPaymentMethod() => AppNavigator.startPaymentMethod();
  void accountSetup() => AppNavigator.startAccountSetup();

  void aboutUs() => AppNavigator.startAboutUs();

  void logout() async {
    var confirm = await Get.dialog(CustomDialog(title: StrRes.logoutHint));
    if (confirm == true) {
      try {
        await UserUtil.logout();
      } catch (e) {
        LogUtil.e(_tag, '登出失败: $e');
        IMViews.showToast('e:$e');
      }
    }
  }

  void kickedOffline({String? tips}) async {
    if (EasyLoading.isShow) {
      EasyLoading.dismiss();
    }
    Get.snackbar(StrRes.accountWarn, tips ?? StrRes.accountException);

    try {
      // 清除RSA相关数据
      await _securityService.clearSecurityData();
    } catch (e) {
      LogUtil.e(_tag, '清除RSA数据失败: $e');
    }

    await DataSp.removeLoginCertificate();
    PushController.logout();
    AppNavigator.startLogin();
  }

  void viewWallet() {
    Get.toNamed(AppRoutes.wallet);
  }

  @override
  void onInit() {
    kickedOfflineSub = imLogic.onKickedOfflineSubject.listen((value) {
      if (value == KickoffType.userTokenInvalid) {
        kickedOffline(tips: StrRes.tokenInvalid);
      } else {
        kickedOffline();
      }
    });
    // 获取身份认证信息
    getIdentityInfo();
    super.onInit();
  }

  @override
  void onClose() {
    kickedOfflineSub.cancel();
    super.onClose();
  }

  // 当页面出现时调用
  @override
  void onReady() {
    super.onReady();
    LogUtil.i(_tag, '我的页面已准备好');
    refreshIdentityInfoIfNeeded();
  }

  // 页面每次获得焦点时调用
  void onPageEnter() {
    LogUtil.i(_tag, '进入我的页面');
    refreshIdentityInfoIfNeeded();
  }

  // 如果需要，刷新身份认证信息
  Future<void> refreshIdentityInfoIfNeeded() async {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    // 限制刷新频率：30秒内只刷新一次
    if (currentTime - _lastRefreshTime < 30000) {
      LogUtil.i(_tag, '短时间内已刷新过身份信息，跳过');
      return;
    }

    // 强制刷新身份认证状态，无论当前状态如何
    LogUtil.i(_tag, '强制刷新身份认证信息');
    await getIdentityInfo();
    _lastRefreshTime = currentTime;
  }

  // 使用直接HTTP请求绕过可能的缓存，强制从服务器获取最新身份认证状态
  Future<IdentityVerifyInfo?> forceRefreshIdentityInfo() async {
    try {
      LogUtil.i(_tag, '开始强制刷新身份认证信息');
      LogUtil.i(_tag, '直接请求URL: ${Urls.identityInfo}');

      // 创建一个包含随机参数的URL以避免缓存
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '${Urls.identityInfo}?_nocache=$timestamp';

      // 直接通过HttpUtil获取数据，绕过Apis层的可能缓存
      final data = await HttpUtil.get(
        url,
        options: Options(
          headers: {
            ...Apis.chatTokenOptions.headers ?? {},
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ),
      );

      LogUtil.i(_tag, '强制刷新返回数据: $data');

      if (data != null) {
        final info = IdentityVerifyInfo.fromJson(data);

        // 更新本地状态
        _identityInfo.value = info;
        _lastRefreshTime = DateTime.now().millisecondsSinceEpoch;

        LogUtil.i(_tag,
            '强制刷新成功: status=${info.status}, verifyTime=${info.verifyTime}');
        return info;
      }
      return null;
    } catch (e) {
      LogUtil.e(_tag, '强制刷新身份认证信息失败: $e');
      return null;
    }
  }

  toQrCodePage() {
    AppNavigator.startMyQrcode();
  }

  // 获取身份认证信息
  Future<void> getIdentityInfo() async {
    try {
      LogUtil.i(_tag, '开始获取身份认证信息');
      LogUtil.i(_tag, '请求URL: ${Urls.identityInfo}');
      LogUtil.i(_tag, '请求Headers: ${Apis.chatTokenOptions.headers}');

      final info = await Apis.getIdentityInfo();

      // 判断状态是否变化
      final oldStatus = _identityInfo.value?.status;
      final newStatus = info?.status;

      LogUtil.i(_tag, '当前身份认证信息: $info');
      LogUtil.i(_tag, '旧状态: $oldStatus, 新状态: $newStatus');

      if (oldStatus != null && newStatus != null && oldStatus != newStatus) {
        LogUtil.i(_tag, '身份认证状态已变更: $oldStatus -> $newStatus');
      }

      if (info != null) {
        _identityInfo.value = info;
        LogUtil.i(_tag,
            '获取身份认证信息成功: status=${info.status}, applyTime=${info.applyTime}, verifyTime=${info.verifyTime}');
      } else {
        LogUtil.i(_tag, '获取身份认证信息成功但返回为null');
        _identityInfo.value = IdentityVerifyInfo(status: 0);
      }
    } catch (e) {
      LogUtil.e(_tag, '获取身份认证信息失败: $e');
      // 失败时设置为待认证状态
      _identityInfo.value = IdentityVerifyInfo(status: 0);
    }
  }

  // 打开身份认证页面前先强制刷新状态
  Future<void> openIdentityVerifyPage() async {
    // 强制刷新以获取最新状态
    final refreshedInfo = await forceRefreshIdentityInfo();
    final currentInfo = refreshedInfo ?? identityInfo;

    // 直接使用 Get.to
    Get.to(
      () => IdentityVerifyPage(initialInfo: currentInfo),
    )?.then((result) {
      if (result != null && result is IdentityVerifyInfo) {
        // 更新本地状态
        _identityInfo.value = result;
        // 重新获取最新状态
        getIdentityInfo();
      } else {
        // 即使用户没有做任何操作，返回时也强制刷新一次
        forceRefreshIdentityInfo();
      }
    });
  }
}
