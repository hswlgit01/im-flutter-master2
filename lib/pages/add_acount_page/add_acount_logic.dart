import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim_common/openim_common.dart';

class AddAcountPageLogic extends GetxController {
  final im = Get.find<IMController>();

  final invitationCodeCtrl = TextEditingController();
  final nicknameCtrl = TextEditingController();
  final orgController = Get.find<OrgController>();

  final enabled = false.obs;
  final avatarFile = Rxn<File>();
  final avatarUrl = ''.obs;
  final nickname = ''.obs;
  final invitationCode = ''.obs;

  @override
  void onInit() {
    invitationCodeCtrl.addListener(_onChanged);
    nicknameCtrl.addListener(_onChanged);

    nickname.value = im.userInfo.value.nickname ?? '';
    nicknameCtrl.text = nickname.value;
    super.onInit();
  }

  @override
  void onClose() {
    invitationCodeCtrl.dispose();
    nicknameCtrl.dispose();
    super.onClose();
  }

  void _onChanged() {
    nickname.value = nicknameCtrl.text.trim();
    invitationCode.value = invitationCodeCtrl.text.trim();
    enabled.value =
        invitationCode.value.isNotEmpty && nickname.value.isNotEmpty;
  }

  /// 选择头像
  void selectAvatar() {
    IMViews.openPhotoSheet(
      onData: (path, url) async {
        if (path != null) {
          avatarFile.value = File(path);
        }
        if (url != null) {
          avatarUrl.value = url;
        }
      },
    );
  }

  /// 提交表单
  void submit() async {
    if (!enabled.value) {
      IMViews.showToast(StrRes.plsCompleteInfo);
      return;
    }

    try {
      await LoadingView.singleton.wrap(
        asyncFunction: () async {
          await _submitJoinRequest();
          
        },
      );

      // 提交成功后的处理
      IMViews.showToast(StrRes.joinInvitationSuccess);
      orgController.refreshOrgList();

      Get.back(result: true);
    } catch (e) {
      IMViews.showToast(e.toString());
    }
  }

  /// 实际的提交逻辑
  Future<void> _submitJoinRequest() async {
    try {
      await Apis.joinInvitation(
        invitationCode.value,
        nickname: nickname.value,
        faceUrl: avatarUrl.value,
      );
    } catch (e) {
      Logger.print('提交加入请求失败: $e');
      rethrow;
    }
  }
}
