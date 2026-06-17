import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../../../../core/controller/im_controller.dart';

class ProcessFriendRequestsLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  late FriendApplicationInfo applicationInfo;

  @override
  void onInit() {
    applicationInfo = Get.arguments['applicationInfo'];
    super.onInit();
  }

  void acceptFriendApplication() async {
    final fromUserID = applicationInfo.fromUserID;
    if (fromUserID == null || fromUserID.isEmpty) {
      IMViews.showToast(StrRes.addFailed);
      return;
    }

    try {
      await LoadingView.singleton.wrap(asyncFunction: () async {
        // dawn 2026-06-17 修复接受好友失败：申请可能已被其它端处理，已成好友时按成功收敛。
        if (await _hasBecomeFriend(fromUserID)) {
          await _syncAcceptedFriend(fromUserID);
          return;
        }

        try {
          await OpenIM.iMManager.friendshipManager.acceptFriendApplication(
            userID: fromUserID,
          );
        } catch (e) {
          if (await _hasBecomeFriend(fromUserID)) {
            Logger.print(
              '[ProcessFriendRequests] accept ignored because already friends: $e',
            );
          } else {
            rethrow;
          }
        }

        await _syncAcceptedFriend(fromUserID);
      });
      _addSuccessfully(null);
    } catch (e) {
      Logger.print('[ProcessFriendRequests] accept friend failed: $e');
      IMViews.showToast(StrRes.addFailed);
    }
  }

  void refuseFriendApplication() async {
    LoadingView.singleton
        .wrap(
            asyncFunction: () => OpenIM.iMManager.friendshipManager
                .refuseFriendApplication(userID: applicationInfo.fromUserID!))
        .then(_rejectSuccessfully)
        .catchError((_) => IMViews.showToast(StrRes.rejectFailed));
  }

  Future<bool> _hasBecomeFriend(String userID) async {
    final relationships = await OpenIM.iMManager.friendshipManager.checkFriend(
      userIDList: [userID],
    );
    return relationships.any(
      (e) => e.userID == userID && e.result == 1,
    );
  }

  Future<void> _syncAcceptedFriend(String userID) async {
    try {
      final friends = await OpenIM.iMManager.friendshipManager.getFriendsInfo(
        userIDList: [userID],
        filterBlack: true,
      );
      if (friends.isNotEmpty) {
        // dawn 2026-06-17 修复接受好友后通讯录不同步：同意后补拉好友详情并广播。
        imLogic.friendAddSubject.addSafely(friends.first);
      }
      imLogic.friendApplicationChangedSubject.addSafely(applicationInfo);
    } catch (e) {
      Logger.print('[ProcessFriendRequests] sync accepted friend ignored: $e');
    }
  }

  _addSuccessfully(_) {
    IMViews.showToast(StrRes.addSuccessfully);
    Get.back(result: 1);
    return _;
  }

  _rejectSuccessfully(_) {
    IMViews.showToast(StrRes.rejectSuccessfully);
    Get.back(result: -1);
    return _;
  }
}
