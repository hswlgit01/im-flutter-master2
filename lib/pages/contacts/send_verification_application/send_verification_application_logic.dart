import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../../../core/controller/im_controller.dart';
import '../group_profile_panel/group_profile_panel_logic.dart';

class SendVerificationApplicationLogic extends GetxController {
  final inputCtrl = TextEditingController();
  String? userID;
  String? groupID;
  JoinGroupMethod? joinGroupMethod;

  bool get isEnterGroup => groupID != null;

  bool get isAddFriend => userID != null;

  @override
  void onInit() {
    userID = Get.arguments['userID'];
    groupID = Get.arguments['groupID'];
    joinGroupMethod = Get.arguments['joinGroupMethod'];
    super.onInit();
  }

  void send() async {
    if (isAddFriend) {
      _applyAddFriend();
    } else if (isEnterGroup) {
      _applyEnterGroup();
    }
  }

  _applyAddFriend() async {
    print('========================================');
    print('[SendVerification] _applyAddFriend 被调用');
    print('[SendVerification] userID=$userID');
    print('[SendVerification] reason=${inputCtrl.text.trim()}');
    print('========================================');

    try {
      print('[SendVerification] ▶️ 准备调用 SDK.addFriend...');

      await LoadingView.singleton.wrap(
        asyncFunction: () {
          print('[SendVerification] ▶️ 开始执行 SDK.addFriend');
          return OpenIM.iMManager.friendshipManager.addFriend(
            userID: userID!,
            reason: inputCtrl.text.trim(),
          );
        },
      );

      print('[SendVerification] ✅ SDK.addFriend 调用成功');
      print('[SendVerification] 准备返回上一页...');

      await _syncAddedFriendToLocalList();
      Get.back();
      IMViews.showToast(StrRes.sendSuccessfully);

      print('[SendVerification] ✅ 好友申请发送完成');
    } catch (error) {
      print('[SendVerification] ❌ SDK.addFriend 调用失败');
      print('[SendVerification] error=$error');
      print('[SendVerification] error.runtimeType=${error.runtimeType}');

      if (error is PlatformException) {
        print('[SendVerification] PlatformException.code=${error.code}');
        print('[SendVerification] PlatformException.message=${error.message}');

        if (error.code == '${SDKErrorCode.refuseToAddFriends}') {
          IMViews.showToast(StrRes.canNotAddFriends);
          return;
        }
      }
      IMViews.showToast(StrRes.sendFailed);
    }
  }

  Future<void> _syncAddedFriendToLocalList() async {
    final targetUserID = userID;
    if (targetUserID == null || targetUserID.isEmpty) return;
    try {
      // dawn 2026-06-17 修复好友申请误入本地通讯录：addFriend 成功只代表申请提交成功，
      // 只有服务端确认双方已是好友时，才补发本地好友变更事件。
      final relationship = await OpenIM.iMManager.friendshipManager.checkFriend(
        userIDList: [targetUserID],
      );
      final isFriend = relationship.any(
        (e) => e.userID == targetUserID && e.result == 1,
      );
      if (!isFriend) return;

      final friends = await OpenIM.iMManager.friendshipManager.getFriendsInfo(
        userIDList: [targetUserID],
        filterBlack: true,
      );
      if (friends.isNotEmpty && Get.isRegistered<IMController>()) {
        Get.find<IMController>().friendAddSubject.addSafely(friends.first);
      }
    } catch (e) {
      Logger.print('[SendVerification] sync added friend ignored: $e');
    }
  }

  _applyEnterGroup() {
    LoadingView.singleton
        .wrap(
          asyncFunction: () => OpenIM.iMManager.groupManager.joinGroup(
            groupID: groupID!,
            reason: inputCtrl.text.trim(),
            joinSource: joinGroupMethod == JoinGroupMethod.qrcode ? 4 : 3,
          ),
        )
        .then((value) => IMViews.showToast(StrRes.sendSuccessfully))
        .then((value) => Get.back())
        .catchError((e) => IMViews.showToast(StrRes.sendFailed));
  }
}
