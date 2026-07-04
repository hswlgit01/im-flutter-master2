import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';
import 'package:sprintf/sprintf.dart';

import '../../../../core/controller/im_controller.dart';
import '../group_setup_logic.dart';

enum GroupMemberOpType {
  view,
  transferRight,
  call,
  at,
  del,
}

class GroupMemberListLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final groupSetupLogic = Get.find<GroupSetupLogic>();
  final controller = RefreshController();
  final memberList = <GroupMembersInfo>[].obs;
  final filteredMemberList = <GroupMembersInfo>[].obs; // 过滤后的成员列表
  final checkedList = <GroupMembersInfo>[].obs;
  final poController = CustomPopupMenuController();
  // dawn 2026-06-14 优化3万人群成员加载：成员页按50个一页滚动加载，避免首次进入拉取500个成员和头像。
  static const int _memberPageSize = 50;
  int count = _memberPageSize;
  final myGroupMemberLevel = 1.obs;
  late GroupInfo groupInfo;
  late GroupMemberOpType opType;
  late StreamSubscription mISub;
  late StreamSubscription _mASub;
  late StreamSubscription _mDSub;

  // 搜索相关
  final searchCtrl = TextEditingController();
  final focusNode = FocusNode();
  final isSearching = false.obs;
  final searchContent = ''.obs;

  bool get isMultiSelMode =>
      opType == GroupMemberOpType.call ||
      opType == GroupMemberOpType.at ||
      opType == GroupMemberOpType.del;

  bool get excludeSelfFromList =>
      opType == GroupMemberOpType.call ||
      opType == GroupMemberOpType.at ||
      opType == GroupMemberOpType.transferRight;

  bool get isDelMember => opType == GroupMemberOpType.del;

  bool get isAdmin => myGroupMemberLevel.value == GroupRoleLevel.admin;

  bool get isOwner => myGroupMemberLevel.value == GroupRoleLevel.owner;

  bool get isOwnerOrAdmin => isAdmin || isOwner;

  int get maxLength => min(groupInfo.memberCount!, 10);

  @override
  void onClose() {
    mISub.cancel();
    _mASub.cancel();
    _mDSub.cancel();
    searchCtrl.dispose();
    focusNode.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    groupInfo = Get.arguments['groupInfo'];
    opType = Get.arguments['opType'];
    mISub = imLogic.memberInfoChangedSubject.listen(_updateMemberLevel);

    // dawn 2026-07-04 修复"入群同意后成员不刷新"：成员列表页实时监听成员加入/退出，
    // 无需退出重进即可看到新成员（去重后追加并排序；退群则移除）。
    _mASub = imLogic.memberAddedSubject.listen((e) {
      if (e.groupID == groupInfo.groupID &&
          memberList.every((m) => m.userID != e.userID)) {
        memberList.add(e);
        _sortMemberList();
        filterMembers();
      }
    });
    _mDSub = imLogic.memberDeletedSubject.listen((e) {
      if (e.groupID == groupInfo.groupID) {
        memberList.removeWhere((m) => m.userID == e.userID);
        filterMembers();
      }
    });

    // 设置搜索监听
    searchCtrl.addListener(() {
      searchContent.value = searchCtrl.text;
      filterMembers();
    });

    super.onInit();
  }

  @override
  void onReady() {
    _queryMyGroupMemberLevel();
    super.onReady();
  }

  void _sortMemberList() {
    memberList.sort((a, b) {
      if (b.roleLevel != a.roleLevel) {
        return (b.roleLevel ?? 0).compareTo(a.roleLevel ?? 0);
      }
      return (b.joinTime ?? 0).compareTo(a.joinTime ?? 0);
    });
  }

  void _updateMemberLevel(GroupMembersInfo e) {
    if (e.groupID == groupInfo.groupID) {
      equal(GroupMembersInfo el) => el.userID == e.userID;
      final member = memberList.firstWhereOrNull(equal);
      if (null != member && e.roleLevel != member.roleLevel) {
        member.roleLevel = e.roleLevel;
      }
      memberList.sort((a, b) {
        if (b.roleLevel != a.roleLevel) {
          return b.roleLevel!.compareTo(a.roleLevel!);
        } else {
          return b.joinTime!.compareTo(a.joinTime!);
        }
      });
    }
  }

  void _queryMyGroupMemberLevel() async {
    LoadingView.singleton.wrap(asyncFunction: () async {
      final list = await OpenIM.iMManager.groupManager.getGroupMembersInfo(
        groupID: groupInfo.groupID,
        userIDList: [OpenIM.iMManager.userID],
      );
      final myInfo = list.firstOrNull;
      if (null != myInfo) {
        myGroupMemberLevel.value = myInfo.roleLevel ?? 1;
      }
      await onLoad();
    });
  }

  Future<List<GroupMembersInfo>> _getGroupMembers() {
    final result = OpenIM.iMManager.groupManager.getGroupMemberList(
      groupID: groupInfo.groupID,
      count: count,
      offset: memberList.length,
      filter: isDelMember ? (isOwner ? 4 : (isAdmin ? 3 : 0)) : 0,
    );

    return result;
  }

  onLoad() async {
    final list = await _getGroupMembers();
    memberList.addAll(list);

    // 更新过滤列表
    filterMembers();

    if (list.length < count) {
      controller.loadNoData();
    } else {
      controller.loadComplete();
    }
  }

  // 根据搜索内容过滤成员
  void filterMembers() {
    if (searchContent.isEmpty) {
      filteredMemberList.value = memberList.toList();
      return;
    }

    final keyword = searchContent.value.toLowerCase();
    filteredMemberList.value = memberList.where((member) {
      // 匹配用户昵称
      final nickname = member.nickname?.toLowerCase() ?? '';
      // 匹配用户ID
      final userID = member.userID?.toLowerCase() ?? '';

      return nickname.contains(keyword) || userID.contains(keyword);
    }).toList();
  }

  bool isChecked(GroupMembersInfo membersInfo) =>
      checkedList.contains(membersInfo);

  clickMember(GroupMembersInfo membersInfo) async {
    if (opType == GroupMemberOpType.transferRight) {
      _transferGroupRight(membersInfo);
      return;
    }
    if (isMultiSelMode) {
      if (isChecked(membersInfo)) {
        checkedList.remove(membersInfo);
      } else if (checkedList.length < maxLength) {
        checkedList.add(membersInfo);
      }
    } else {
      viewMemberInfo(membersInfo);
    }
  }

  static _transferGroupRight(GroupMembersInfo membersInfo) async {
    var confirm = await Get.dialog(CustomDialog(
      title: sprintf(StrRes.confirmTransferGroupToUser, [membersInfo.nickname]),
    ));
    if (confirm == true) {
      Get.back(result: membersInfo);
    }
  }

  void removeSelectedMember(GroupMembersInfo membersInfo) {
    checkedList.remove(membersInfo);
  }

  viewMemberInfo(GroupMembersInfo membersInfo) {
    if (!isOwnerOrAdmin) {
      if (groupInfo.lookMemberInfo != 1) {
        AppNavigator.startUserProfilePane(
          userID: membersInfo.userID!,
          groupID: membersInfo.groupID,
          nickname: membersInfo.nickname,
          faceURL: membersInfo.faceURL,
        );
      }
    } else {
      AppNavigator.startUserProfilePane(
        userID: membersInfo.userID!,
        groupID: membersInfo.groupID,
        nickname: membersInfo.nickname,
        faceURL: membersInfo.faceURL,
      );
    }
  }

  void addMember() async {
    poController.hideMenu();
    await groupSetupLogic.addMember();
    refreshData();
  }

  void refreshData() {
    LoadingView.singleton.wrap(asyncFunction: () async {
      memberList.clear();
      await onLoad();
    });
  }

  void delMember() async {
    poController.hideMenu();
    await groupSetupLogic.removeMember();
    refreshData();
  }

  void clearSearch() {
    searchCtrl.clear();
    focusNode.unfocus();
  }

  static _buildEveryoneMemberInfo() => GroupMembersInfo(
        userID: OpenIM.iMManager.conversationManager.atAllTag,
        nickname: 'all',
      );

  void selectEveryone() {
    Get.back(result: <GroupMembersInfo>[_buildEveryoneMemberInfo()]);
  }

  void confirmSelectedMember() {
    Get.back(result: checkedList.value);
  }

  bool hiddenMember(GroupMembersInfo membersInfo) =>
      excludeSelfFromList && membersInfo.userID == OpenIM.iMManager.userID;
}
