import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/pages/chat/group_setup/group_setup_logic.dart';
import 'package:openim_common/openim_common.dart';

import '../../../../routes/app_navigator.dart';
import '../group_member_list/group_member_list_logic.dart';

class GroupManageLogic extends GetxController {
  final groupSetupLogic = Get.find<GroupSetupLogic>();

  Rx<GroupInfo> get groupInfo => groupSetupLogic.groupInfo;

  String get needVerificationStr {
    switch (groupInfo.value.needVerification) {
      case GroupVerification.applyNeedVerificationInviteDirectly:
        return StrRes.inviteNotVerification;
      case GroupVerification.allNeedVerification:
        return StrRes.needVerification;
      case GroupVerification.directly:
        return StrRes.allowAnyoneJoinGroup;
      case 3:
        return StrRes.noOneCanJoin;
      default:
        return "";
    }
  }

  String get lookMemberInfoStr {
    switch (groupInfo.value.lookMemberInfo) {
      case 1:
        return StrRes.notAllowSeeMemberProfile;
      case 0:
        return StrRes.allowAnyoneViewMemberProfile;
      case 2:
        return StrRes.disallowViewMemberCountAndList;
      case 3:
        return StrRes.disallowAdminViewMembers;
      default:
        return "";
    }
  }

  void transferGroupOwnerRight() async {
    var result = await AppNavigator.startGroupMemberList(
      groupInfo: groupInfo.value,
      opType: GroupMemberOpType.transferRight,
    );
    if (result is GroupMembersInfo) {
      await LoadingView.singleton.wrap(
        asyncFunction: () => OpenIM.iMManager.groupManager.transferGroupOwner(
          groupID: groupInfo.value.groupID,
          userID: result.userID!,
        ),
      );
      groupInfo.update((val) {
        val?.ownerUserID = result.userID;
      });
      Get.back();
    }
  }

  void changeGroupMute(bool mute) async {
    await LoadingView.singleton.wrap(
      asyncFunction: () => OpenIM.iMManager.groupManager.changeGroupMute(
        groupID: groupInfo.value.groupID,
        mute: mute,
      ),
    );
    groupInfo.update((val) {
      val?.status = mute ? 3 : 1;
    });
  }

  setLookMemberInfo(int state) async {
    await LoadingView.singleton.wrap(asyncFunction: () {
      return OpenIM.iMManager.groupManager.setGroupInfo(GroupInfo(
        groupID: groupInfo.value.groupID,
        lookMemberInfo: state,
      ));
    });
    groupInfo.update((val) {
      val?.lookMemberInfo = state;
    });
  }

  setApplyMemberFriend(int state) async {
    await LoadingView.singleton.wrap(asyncFunction: () {
      return OpenIM.iMManager.groupManager.setGroupInfo(GroupInfo(
        groupID: groupInfo.value.groupID,
        applyMemberFriend: state,
      ));
    });
    groupInfo.update((val) {
      val?.applyMemberFriend = state;
    });
  }
  selectInGroupSelect() {
    Get.bottomSheet(BottomSheetView(items: [
      SheetItem(
        label: StrRes.allowAnyoneJoinGroup,
        onTap: () => setNeedVerification(GroupVerification.directly),
      ),
      SheetItem(
        label: StrRes.inviteNotVerification,
        onTap: () => setNeedVerification(GroupVerification.applyNeedVerificationInviteDirectly),
      ),
      SheetItem(
        label: StrRes.needVerification,
        onTap: () => setNeedVerification(GroupVerification.allNeedVerification),
      ),
      SheetItem(
        label: StrRes.noOneCanJoin,
        onTap: () => setNeedVerification(3),
      ),
    ]));
  }

  selectLookMemberInfoSelect() {
    Get.bottomSheet(BottomSheetView(items: [
      SheetItem(
        label: StrRes.allowAnyoneViewMemberProfile,
        onTap: () => setLookMemberInfo(0),
        isChecked: groupInfo.value.lookMemberInfo == 0,
      ),
      SheetItem(
        label: StrRes.notAllowSeeMemberProfile,
        isChecked: groupInfo.value.lookMemberInfo == 1,
        isIMChecked: [2, 3].contains(groupInfo.value.lookMemberInfo),
        onTap: () => setLookMemberInfo(1),
      ),
      SheetItem(
        label: StrRes.disallowViewMemberCountAndList,
        isChecked: groupInfo.value.lookMemberInfo == 2,
        isIMChecked: [3].contains(groupInfo.value.lookMemberInfo),
        onTap: () => setLookMemberInfo(2),
      ),
      SheetItem(
        label: StrRes.disallowAdminViewMembers,
        isChecked: groupInfo.value.lookMemberInfo == 3,
        onTap: () => setLookMemberInfo(3),
      ),
    ]));
  }

  setNeedVerification(int state) {
    LoadingView.singleton.wrap(asyncFunction: () {
      return OpenIM.iMManager.groupManager.setGroupInfo(GroupInfo(
        groupID: groupInfo.value.groupID,
        needVerification: state,
      ));
    });
    groupInfo.update((val) {
      val?.needVerification = state;
    });
  }
}
