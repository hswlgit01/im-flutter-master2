import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../../../core/controller/im_controller.dart';

enum EditAttr {
  nickname,
  englishName,
  telephone,
  mobile,
  email,
}

class EditMyInfoLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  late TextEditingController inputCtrl;
  final FocusNode focusNode = FocusNode();
  late TextEditingController verificationCodeCtrl;
  late EditAttr editAttr;
  late int maxLength;
  String? title;
  String? defaultValue;
  TextInputType? keyboardType;
  // 邮箱验证相关
  final isEmailEdit = false.obs;
  final showVerificationSection = false.obs;
  final verificationCodeSent = false.obs;

  // 内容是否有修改
  final hasContentChanged = false.obs;

  @override
  void onInit() {
    editAttr = Get.arguments['editAttr'];
    maxLength = Get.arguments['maxLength'] ?? 16;
    _initAttr();
    inputCtrl = TextEditingController(text: defaultValue);
    verificationCodeCtrl = TextEditingController();
    // 监听邮箱输入变化
    if (editAttr == EditAttr.email) {
      isEmailEdit.value = true;
      inputCtrl.addListener(_onEmailChanged);
    }

    focusNode.addListener(() {
      inputCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: inputCtrl.text.length
      );
    });

    // 监听内容变化
    inputCtrl.addListener(_onContentChanged);

    super.onInit();
  }

  @override
  void onClose() {
    inputCtrl.dispose();
    focusNode.dispose();
    verificationCodeCtrl.dispose();
    super.onClose();
  }

  void _onEmailChanged() {
    final currentEmail = inputCtrl.text.trim();
    final originalEmail = imLogic.userInfo.value.email ?? '';

    // 如果邮箱改变了且新邮箱不为空，显示验证码区域
    if (currentEmail != originalEmail && currentEmail.isNotEmpty) {
      showVerificationSection.value = true;
    } else {
      showVerificationSection.value = false;
      verificationCodeSent.value = false;
    }
  }

  void _onContentChanged() {
    final currentValue = inputCtrl.text.trim();
    hasContentChanged.value = currentValue != (defaultValue ?? '');
  }

  _initAttr() {
    switch (editAttr) {
      case EditAttr.nickname:
        title = StrRes.name;
        defaultValue = imLogic.userInfo.value.nickname;
        keyboardType = TextInputType.text;
        break;
      case EditAttr.englishName:
        break;
      case EditAttr.telephone:
        break;
      case EditAttr.mobile:
        title = StrRes.mobile;
        defaultValue = imLogic.userInfo.value.phoneNumber;
        keyboardType = TextInputType.phone;
        break;
      case EditAttr.email:
        title = StrRes.email;
        defaultValue = imLogic.userInfo.value.email;
        keyboardType = TextInputType.emailAddress;
        break;
    }
  }

  // 发送邮箱验证码
  Future<bool> sendEmailVerificationCode() async {
    final email = inputCtrl.text.trim();
    if (email.isEmpty || !email.isEmail) {
      IMViews.showToast(StrRes.plsEnterRightEmail);
      return false;
    }

    final success = await LoadingView.singleton.wrap(
      asyncFunction: () => Apis.requestVerificationCode(
        email: email,
        usedFor: 5, // 用于修改邮箱
      ),
    );
    if (success) {
      verificationCodeSent.value = true;
      IMViews.showToast(StrRes.verificationCodeSent);
    }
    return success;
  }

  void save() async {
    final value = inputCtrl.text.trim();

    if (editAttr == EditAttr.nickname) {
      await LoadingView.singleton.wrap(
        asyncFunction: () => Apis.updateUserInfo(
          userID: OpenIM.iMManager.userID,
          nickname: value,
        ),
      );
      imLogic.userInfo.update((val) {
        val?.nickname = value;
      });
    } else if (editAttr == EditAttr.mobile) {
      await LoadingView.singleton.wrap(
        asyncFunction: () => Apis.updateUserInfo(
          userID: OpenIM.iMManager.userID,
          phoneNumber: value,
        ),
      );
      imLogic.userInfo.update((val) {
        val?.phoneNumber = value;
      });
    } else if (editAttr == EditAttr.email) {
      // 邮箱验证逻辑
      if (defaultValue?.isNotEmpty == true && value.isEmpty) {
        IMViews.showToast(StrRes.plsEnterEmail);
        return;
      }
      // 如果邮箱发生了变化，需要验证验证码
      final originalEmail = imLogic.userInfo.value.email ?? '';
      if (value != originalEmail && value.isNotEmpty) {
        if (!verificationCodeSent.value) {
          IMViews.showToast(StrRes.plsSendVerificationCodeFirst);
          return;
        }
      }
      final code = verificationCodeCtrl.text.trim();

      if (code.isEmpty) {
        IMViews.showToast(StrRes.plsEnterVerificationCode);
        return;
      }
      await LoadingView.singleton.wrap(
        asyncFunction: () => Apis.updateEmail(newEmail: value, verifyCode: code),
      );

      imLogic.userInfo.update((val) {
        val?.email = value;
      });
    }
    Get.back();
  }
}
