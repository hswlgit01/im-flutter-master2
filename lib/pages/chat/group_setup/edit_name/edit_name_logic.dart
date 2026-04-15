import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/pages/chat/group_setup/group_setup_logic.dart';
import 'package:openim_common/openim_common.dart';

enum EditNameType {
  myGroupMemberNickname,
  groupNickname,
}

class EditGroupNameLogic extends GetxController {
  final groupSetupLogic = Get.find<GroupSetupLogic>();
  late TextEditingController inputCtrl;
  late EditNameType type;
  String? faceUrl;

  @override
  void onInit() {
    type = Get.arguments['type'];
    faceUrl = Get.arguments['faceUrl'];
    inputCtrl = TextEditingController(
      text: type == EditNameType.groupNickname ? groupSetupLogic.groupInfo.value.groupName : groupSetupLogic.myGroupMembersInfo.value.nickname,
    );
    super.onInit();
  }

  @override
  void onClose() {
    inputCtrl.dispose();
    super.onClose();
  }

  String? get title => type == EditNameType.myGroupMemberNickname ? StrRes.myGroupMemberNickname : StrRes.groupName;

  void save() async {
    if (inputCtrl.text.trim().length > 16) {
      return IMViews.showToast(StrRes.createGroupTips);
    }
    final newName = inputCtrl.text.trim();
    await LoadingView.singleton.wrap(asyncFunction: () async {
      if (type == EditNameType.groupNickname) {
        await OpenIM.iMManager.groupManager
            .setGroupInfo(GroupInfo(groupID: groupSetupLogic.groupInfo.value.groupID, groupName: newName));
        // 修改成功后立即更新本地群信息，保证返回群设置页时显示新名称
        groupSetupLogic.groupInfo.update((val) {
          val?.groupName = newName;
        });
      } else if (type == EditNameType.myGroupMemberNickname) {
        await OpenIM.iMManager.groupManager.setGroupMemberNickname(
          groupID: groupSetupLogic.groupInfo.value.groupID,
          userID: OpenIM.iMManager.userID,
          groupNickname: newName,
        );
        groupSetupLogic.myGroupMembersInfo.update((val) {
          val?.nickname = newName;
        });
      }
    });
    IMViews.showToast(StrRes.setSuccessfully);
    Get.back();
  }
}
