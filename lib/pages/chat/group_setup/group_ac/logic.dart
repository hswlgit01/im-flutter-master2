import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:openim_common/openim_common.dart';

class GroupAcLogic extends GetxController {
  late Rx<GroupInfo> groupInfo;
  late Rx<PublicUserInfo> userInfo;
  late RxString value = ''.obs;
  FocusNode focusNode = FocusNode();
  RxBool isEdit = false.obs;
  final groupMembersInfo = Rx<GroupMembersInfo?>(null);

  // 添加一个控制输入框内容的控制器
  final textController = TextEditingController();

  bool get isOwner => groupInfo.value.ownerUserID == OpenIM.iMManager.userID;
  bool get isAdmin => groupMembersInfo?.value?.roleLevel == GroupRoleLevel.admin;

  bool get isOwnerOrAdmin => isOwner || isAdmin;

  @override
  onInit() {
    groupInfo = Rx(Get.arguments['groupInfo']);
    if (groupInfo.value.notificationUserID != null) {
      _getUserInfo(groupInfo.value.notificationUserID!);
    }
    _getGroupUserInfo(groupId: groupInfo.value.groupID);
    super.onInit();
  }

  _getUserInfo(String id) async {
    userInfo = Rx(PublicUserInfo());
    final result =
        await OpenIM.iMManager.userManager.getUsersInfo(userIDList: [id]);
    userInfo.value = result.firstOrNull ?? PublicUserInfo();
  }

  _getGroupUserInfo({required String groupId}) async {
    userInfo = Rx(PublicUserInfo());
    final userId = OpenIM.iMManager.userID;
    final result = await OpenIM.iMManager.groupManager
        .getGroupMembersInfo(groupID: groupId, userIDList: [userId]);
    if (result.isNotEmpty) {
      groupMembersInfo.value = result.first;
    }
  }

  Future<void> saveGroupAnnouncement() async {
    String announcement = textController.text.trim();
    try {
      // 显示加载中效果
      await LoadingView.singleton.wrap(
        asyncFunction: () => OpenIM.iMManager.groupManager.setGroupInfo(
            GroupInfo(
                groupID: groupInfo.value.groupID, notification: announcement)),
      );

      // 保存成功后更新群公告
      groupInfo.update((info) {
        if (info != null) {
          info.notification = announcement;
        }
      });
      Get.back();
      // 显示成功提示
      EasyLoading.showToast("群公告已更新");
    } catch (e) {
      // 捕获异常并显示错误提示
      // Get.snackbar('错误', '更新群公告失败: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }
}
