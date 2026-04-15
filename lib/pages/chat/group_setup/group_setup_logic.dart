import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/org_controller.dart';
import 'package:openim_common/openim_common.dart';
import 'package:synchronized/synchronized.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../../core/controller/app_controller.dart';
import '../../../core/controller/im_controller.dart';
import '../../../routes/app_navigator.dart';
import '../../contacts/select_contacts/select_contacts_logic.dart';
import '../../conversation/conversation_logic.dart';
import '../chat_logic.dart';
import 'edit_name/edit_name_logic.dart';
import 'group_member_list/group_member_list_logic.dart';

class GroupSetupLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final orgController = Get.find<OrgController>();

  final chatLogic = Get.find<ChatLogic>(tag: GetTags.chat);
  final appLogic = Get.find<AppController>();
  final conversationLogic = Get.find<ConversationLogic>();
  final memberList = <GroupMembersInfo>[].obs;
  late Rx<ConversationInfo> conversationInfo;
  late Rx<GroupInfo> groupInfo;
  late Rx<GroupMembersInfo> myGroupMembersInfo;
  late StreamSubscription _guSub;
  late StreamSubscription _mASub;
  late StreamSubscription _mISub;
  late StreamSubscription _mDSub;
  late StreamSubscription _ccSub;
  late StreamSubscription _jasSub;
  late StreamSubscription _jdsSub;
  final lock = Lock();
  final isJoinedGroup = false.obs;
  final avatar = Rx<File?>(null);

  @override
  void onInit() async {
    if (Get.arguments['conversationInfo'] != null) {
      conversationInfo = Rx(Get.arguments['conversationInfo']);
    } else {
      final temp = await OpenIM.iMManager.conversationManager
          .getOneConversation(
              sourceID: chatLogic.conversationInfo.isGroupChat
                  ? chatLogic.conversationInfo.groupID!
                  : chatLogic.conversationInfo.userID!,
              sessionType: chatLogic.conversationInfo.conversationType!);
      conversationInfo = Rx(temp);
    }
    groupInfo = Rx(_defaultGroupInfo);
    myGroupMembersInfo = Rx(_defaultMemberInfo);

    _ccSub = imLogic.conversationChangedSubject.listen((newList) {
      final newValue = newList.firstWhereOrNull((element) =>
          element.conversationID == conversationInfo.value.conversationID);
      if (newValue != null) {
        conversationInfo.update((val) {
          val?.isPinned = newValue.isPinned;

          val?.recvMsgOpt = newValue.recvMsgOpt;
          val?.isMsgDestruct = newValue.isMsgDestruct;
          val?.msgDestructTime = newValue.msgDestructTime;
        });
      }
    });

    _guSub = imLogic.groupInfoUpdatedSubject.listen((value) {
      if (value.groupID == groupInfo.value.groupID) {
        _updateGroupInfo(value);
      }
    });

    _jasSub = imLogic.joinedGroupAddedSubject.listen((value) {
      if (value.groupID == groupInfo.value.groupID) {
        isJoinedGroup.value = true;
        _queryAllInfo();
      }
    });

    _jdsSub = imLogic.joinedGroupDeletedSubject.listen((value) {
      if (value.groupID == groupInfo.value.groupID) {
        isJoinedGroup.value = false;
      }
    });

    _mISub = imLogic.memberInfoChangedSubject.listen((e) {
      if (e.groupID == groupInfo.value.groupID &&
          e.userID == myGroupMembersInfo.value.userID) {
        myGroupMembersInfo.update((val) {
          val?.nickname = e.nickname;
          val?.roleLevel = e.roleLevel;
        });
      }
      if (e.groupID == groupInfo.value.groupID &&
          e.userID == groupInfo.value.ownerUserID) {
        var index = memberList.indexWhere(
            (element) => element.userID == groupInfo.value.ownerUserID);
        if (index == -1) {
          memberList.insert(0, e);
        } else if (index != 0) {
          memberList.insert(0, memberList.removeAt(index));
        }
      }
      memberList.sort((a, b) {
        if (b.roleLevel != a.roleLevel) {
          return b.roleLevel!.compareTo(a.roleLevel!);
        } else {
          return b.joinTime!.compareTo(a.joinTime!);
        }
      });
    });
    _mASub = imLogic.memberAddedSubject.listen((e) async {
      if (e.groupID == groupInfo.value.groupID) {
        if (e.userID == OpenIM.iMManager.userID) {
          isJoinedGroup.value = true;
          _queryAllInfo();
        } else {
          memberList.add(e);
        }
      }
    });
    _mDSub = imLogic.memberDeletedSubject.listen((e) {
      if (e.groupID == groupInfo.value.groupID) {
        if (e.userID == OpenIM.iMManager.userID) {
          isJoinedGroup.value = false;
        } else {
          memberList.removeWhere((element) => element.userID == e.userID);
        }
      }
    });
    super.onInit();
  }

  @override
  void onReady() {
    _checkIsJoinedGroup();
    super.onReady();
  }

  @override
  void onClose() {
    _guSub.cancel();
    _mASub.cancel();
    _mDSub.cancel();
    _ccSub.cancel();
    _mISub.cancel();
    _jdsSub.cancel();
    _jasSub.cancel();
    super.onClose();
  }

  get _defaultGroupInfo => GroupInfo(
        groupID: conversationInfo.value.groupID!,
        groupName: conversationInfo.value.showName,
        faceURL: conversationInfo.value.faceURL,
        memberCount: 0,
      );

  get _defaultMemberInfo => GroupMembersInfo(
        userID: OpenIM.iMManager.userID,
        nickname: OpenIM.iMManager.userInfo.nickname,
      );

  bool get isOwnerOrAdmin => isOwner || isAdmin;

  bool get isAdmin =>
      myGroupMembersInfo.value.roleLevel == GroupRoleLevel.admin;

  bool get isNotDisturb => conversationInfo.value.recvMsgOpt != 0;

  bool get isOwner => groupInfo.value.ownerUserID == OpenIM.iMManager.userID;

  String get conversationID => conversationInfo.value.conversationID;

  bool get isShowMember => ((groupInfo.value.lookMemberInfo ?? 0) - (isOwner ? 2 : (isAdmin ? 1 : 0))) < 2;

  void _checkIsJoinedGroup() async {
    isJoinedGroup.value = await OpenIM.iMManager.groupManager.isJoinedGroup(
      groupID: groupInfo.value.groupID,
    );
    _queryAllInfo();
  }

  void _queryAllInfo() {
    if (isJoinedGroup.value) {
      getGroupInfo();
      getGroupMembers();
      getMyGroupMemberInfo();
    }
  }

  getGroupMembers() async {
    var list = await OpenIM.iMManager.groupManager.getGroupMemberList(
      groupID: groupInfo.value.groupID,
      count: 10,
    );
    memberList.assignAll(list);
  }

  getGroupInfo() async {
    var list = await OpenIM.iMManager.groupManager.getGroupsInfo(
      groupIDList: [groupInfo.value.groupID],
    );
    var value = list.firstOrNull;
    if (null != value) {
      _updateGroupInfo(value);
    }
  }

  getMyGroupMemberInfo() async {
    final list = await OpenIM.iMManager.groupManager.getGroupMembersInfo(
      groupID: groupInfo.value.groupID,
      userIDList: [OpenIM.iMManager.userID],
    );
    final info = list.firstOrNull;
    if (null != info) {
      myGroupMembersInfo.update((val) {
        val?.nickname = info.nickname;
        val?.roleLevel = info.roleLevel;
      });
    }
  }

  toGroupAc() {
    AppNavigator.startGroupAc(groupInfo: groupInfo.value);
  }

  void _updateGroupInfo(GroupInfo value) {
    groupInfo.update((val) {
      val?.groupName = value.groupName;
      val?.faceURL = value.faceURL;
      val?.notification = value.notification;
      val?.introduction = value.introduction;
      val?.memberCount = value.memberCount;
      val?.ownerUserID = value.ownerUserID;
      val?.status = value.status;
      val?.needVerification = value.needVerification;
      val?.groupType = value.groupType;
      val?.lookMemberInfo = value.lookMemberInfo;
      val?.applyMemberFriend = value.applyMemberFriend;
      val?.notificationUserID = value.notificationUserID;
      val?.notificationUpdateTime = value.notificationUpdateTime;
      val?.ex = value.ex;
    });
  }

  void modifyGroupAvatar() async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      Get.context!,
      pickerConfig:
          const AssetPickerConfig(maxAssets: 1, requestType: RequestType.image),
    );
    if (assets != null) {
      final file = await assets.first.file;
      final result = await IMViews.uCropPic(file!.path);

      final path = result['path'];
      final url = result['url'];

      if (url != null) {
        avatar.value = File(path);
        await _modifyGroupInfo(faceUrl: url);
        groupInfo.update((val) {
          val?.faceURL = url;
        });
      }
    }
  }

  void modifyGroupName(String? faceUrl) => AppNavigator.startEditGroupName(
        type: EditNameType.groupNickname,
        faceUrl: faceUrl,
      );

  _modifyGroupInfo({
    String? groupName,
    String? notification,
    String? introduction,
    String? faceUrl,
  }) =>
      OpenIM.iMManager.groupManager.setGroupInfo(GroupInfo(
        groupID: groupInfo.value.groupID,
        groupName: groupName,
        notification: notification,
        introduction: introduction,
        faceURL: faceUrl,
      ));

  void viewGroupQrcode() => AppNavigator.startGroupQrcode();

  void viewGroupMembers() => AppNavigator.startGroupMemberList(
        groupInfo: groupInfo.value,
      );

  void groupManage() => AppNavigator.startGroupManage(
        groupInfo: groupInfo.value,
      );

  void _removeConversation() async {
    await OpenIM.iMManager.conversationManager
        .deleteConversationAndDeleteAllMsg(
      conversationID: conversationInfo.value.conversationID,
    );
  }

  void quitGroup() async {
    if (isJoinedGroup.value) {
      if (isOwner) {
        var confirm = await Get.dialog(CustomDialog(
          title: StrRes.dismissGroupHint,
        ));
        if (confirm == true) {
          await OpenIM.iMManager.groupManager.dismissGroup(
            groupID: groupInfo.value.groupID,
          );
        } else {
          return;
        }
      } else {
        var confirm = await Get.dialog(CustomDialog(
          title: StrRes.quitGroupHint,
        ));
        if (confirm == true) {
          await OpenIM.iMManager.groupManager.quitGroup(
            groupID: groupInfo.value.groupID,
          );
        } else {
          return;
        }
      }
    } else {
      _removeConversation();
      conversationLogic.list.removeWhere((e) => e.conversationID == conversationID);
    }

    AppNavigator.startBackMain();
  }

  clearChatHistory() async {
    var confirm = await Get.dialog(CustomDialog(
      title: StrRes.confirmClearChatHistory,
    ));
    if (confirm == true) {
      LoadingView.singleton
          .wrap(
        asyncFunction: () => OpenIM.iMManager.conversationManager
            .clearConversationAndDeleteAllMsg(
          conversationID: conversationInfo.value.conversationID,
        ),
      )
          .then((value) {
        chatLogic.clearAllMessage();
        IMViews.showToast(StrRes.clearSuccessfully);
      });
    }
  }

  void copyGroupID() {
    IMUtils.copy(text: groupInfo.value.groupID);
  }

  int length() {
    int buttons;
    if (isOwnerOrAdmin) {
      buttons = 2; // 管理员和群主显示添加和删除按钮
    } else if (groupInfo.value.needVerification == 3) {
      buttons = 0; // 当 needVerification == 3 时，普通成员不显示任何按钮
    } else {
      buttons = 1; // 普通成员只显示添加按钮
    }
    return (memberList.length + buttons) > 10
        ? 10
        : (memberList.length + buttons);
  }

  Widget itemBuilder({
    required int index,
    required Widget Function(GroupMembersInfo info) builder,
    required Widget Function() addButton,
    required Widget Function() delButton,
  }) {
    // 根据用户权限和群设置计算成员显示数量
    var length;
    if (isOwnerOrAdmin) {
      length = 8; // 管理员和群主显示8个成员，剩余2个位置给添加和删除按钮
    } else if (groupInfo.value.needVerification == 3) {
      length = 10; // 当 needVerification == 3 时，普通成员显示10个成员，不显示按钮
    } else {
      length = 9; // 普通成员显示9个成员，剩余1个位置给添加按钮
    }
    
    if (memberList.length > length) {
      if (index < length) {
        var info = memberList.elementAt(index);
        return builder(info);
      } else if (index == length && (isOwnerOrAdmin || groupInfo.value.needVerification != 3)) {
        return addButton();
      } else if (index == length + 1 && isOwnerOrAdmin) {
        return delButton();
      }
    } else {
      if (index < memberList.length) {
        var info = memberList.elementAt(index);
        return builder(info);
      } else if (index == memberList.length && (isOwnerOrAdmin || groupInfo.value.needVerification != 3)) {
        return addButton();
      } else if (index == memberList.length + 1 && isOwnerOrAdmin) {
        return delButton();
      }
    }
    
    // 如果没有匹配的条件，返回空容器
    return const SizedBox.shrink();
  }

  addMember() async {
    final result = await AppNavigator.startSelectContacts(
      action: SelAction.addMember,
      groupID: groupInfo.value.groupID,
    );

    final list = IMUtils.convertSelectContactsResultToUserID(result);
    if (list is List<String>) {
      try {
        await LoadingView.singleton.wrap(
          asyncFunction: () => OpenIM.iMManager.groupManager.inviteUserToGroup(
            groupID: groupInfo.value.groupID,
            userIDList: list,
            reason: 'Come on baby',
          ),
        );
      } catch (_) {}
      getGroupMembers();
    }
  }

  removeMember() async {
    final list = await AppNavigator.startGroupMemberList(
      groupInfo: groupInfo.value,
      opType: GroupMemberOpType.del,
    );
    if (list is List<GroupMembersInfo>) {
      var removeUidList = list.map((e) => e.userID!).toList();
      try {
        await LoadingView.singleton.wrap(
          asyncFunction: () => OpenIM.iMManager.groupManager.kickGroupMember(
            groupID: groupInfo.value.groupID,
            userIDList: removeUidList,
            reason: 'Get out baby',
          ),
        );
        getGroupMembers();
      } catch (e) {
        // 根据错误码识别官方账号保护错误
        try {
          final dynamic exception = e;
          final errorCode = exception.code;

          // 1208 = OfficialAccountProtected
          if (errorCode == 1208 || errorCode == '1208') {
            IMViews.showToast('此用户为官方客服，无法移出');
            return;
          }
        } catch (_) {}

        // 通用错误提示
        IMViews.showToast('操作失败，请稍后重试');
      }
    }
  }

  void viewMemberInfo(GroupMembersInfo membersInfo) {
    if (!isOwnerOrAdmin) {
      if (groupInfo.value.lookMemberInfo != 1) {
        AppNavigator.startUserProfilePane(
          userID: membersInfo.userID!,
          nickname: membersInfo.nickname,
          faceURL: membersInfo.faceURL,
          groupID: membersInfo.groupID,
        );
      }
    } else {
      AppNavigator.startUserProfilePane(
        userID: membersInfo.userID!,
        nickname: membersInfo.nickname,
        faceURL: membersInfo.faceURL,
        groupID: membersInfo.groupID,
      );
    }
  }

  void setRecvMsgOpt() {
    final oldState = conversationInfo.value.recvMsgOpt;
    final newState = oldState == 0 ? 2 : 0;
    LoadingView.singleton.wrap(asyncFunction: () {
      return OpenIM.iMManager.conversationManager.setConversation(
          conversationID, ConversationReq(recvMsgOpt: newState));
    }).then((_) {
      conversationInfo.update((val) {
        val?.recvMsgOpt = newState;
      });
    }).catchError((e) {
      IMViews.showToast(e.toString());
    });
  }

  toQrCodePage() {
    AppNavigator.startGroupQrcode();
  }

  shareGroup() async {
    final result =
        await AppNavigator.startSelectContacts(action: SelAction.forward);
    if (result != null && result is Map && result['checkedList'] != null) {
      final checkedList = result['checkedList'];
      for (final item in checkedList) {
        final message = await IMUtils.createGroupCardMessage(
            groupID: groupInfo.value.groupID,
            groupName: groupInfo.value.groupName ?? "",
            groupAvatar: groupInfo.value.faceURL ?? "");
        final userID = IMUtils.convertCheckedToUserID(item);
        final groupID = IMUtils.convertCheckedToGroupID(item);

        /// 更新本地消息
        if (chatLogic.groupID == groupID) {
          chatLogic.sendMessage(message);
        } else {
          OpenIM.iMManager.messageManager.sendMessage(
              message: message,
              userID: userID,
              groupID: groupID,
              offlinePushInfo: Config.offlinePushInfo);
        }
      }
      IMViews.showToast('已发送');
    }
  }
}
