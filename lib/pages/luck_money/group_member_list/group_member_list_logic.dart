import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

import '../../../../core/controller/im_controller.dart';

class LuckMoneyGroupMemberListLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final controller = RefreshController();
  final memberList = <GroupMembersInfo>[].obs;
  final filteredMemberList = <GroupMembersInfo>[].obs; // 过滤后的成员列表
  final poController = CustomPopupMenuController();
  int count = 500;
  final myGroupMemberLevel = 1.obs;
  late GroupInfo groupInfo;
  late StreamSubscription mISub;

  // 搜索相关
  final searchCtrl = TextEditingController();
  final focusNode = FocusNode();
  final isSearching = false.obs;
  final searchContent = ''.obs;

  bool isMultiSelMode = false;
  bool isDelMember = false;
  bool isAdmin = false;
  bool isOwner = false;
  bool isOwnerOrAdmin = false;

  int get maxLength => min(groupInfo.memberCount!, 10);

  @override
  void onClose() {
    mISub.cancel();
    searchCtrl.dispose();
    focusNode.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    groupInfo = Get.arguments['groupInfo'];
    mISub = imLogic.memberInfoChangedSubject.listen(_updateMemberLevel);

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

    count = 100;

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

      return nickname.contains(keyword) ||
             userID.contains(keyword);
    }).toList();
  }

  void clearSearch() {
    searchCtrl.clear();
    focusNode.unfocus();
  }

  clickMember(GroupMembersInfo membersInfo) async {
    return Get.back(result: membersInfo);
  }

  // Search functionality removed due to redesign
  // Now using inline search in the group member list

  static _buildEveryoneMemberInfo() => GroupMembersInfo(
      userID: OpenIM.iMManager.conversationManager.atAllTag,
      nickname: StrRes.everyone,
    );

  void selectEveryone() {
    Get.back(result: <GroupMembersInfo>[_buildEveryoneMemberInfo()]);
  }

}
