import 'dart:async';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';

import '../../../core/controller/im_controller.dart';
import '../../home/home_logic.dart';

class FriendRequestsLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final homeLogic = Get.find<HomeLogic>();
  final applicationList = <FriendApplicationInfo>[].obs;
  late StreamSubscription faSub;

  @override
  void onInit() {
    faSub = imLogic.friendApplicationChangedSubject.listen((value) {
      _getFriendRequestsList();
    });
    super.onInit();
  }

  @override
  void onReady() {
    _getFriendRequestsList();
    super.onReady();
  }

  @override
  void onClose() {
    faSub.cancel();
    homeLogic.getUnhandledFriendApplicationCount();
    super.onClose();
  }

  void _getFriendRequestsList() async {
    try {
      final list = await Future.wait([
        OpenIM.iMManager.friendshipManager.getFriendApplicationListAsRecipient(
          // dawn 2026-06-17 修复新的好友页面为空：显式分页拉取收到的好友申请。
          req: GetFriendApplicationListAsRecipientReq(offset: 0, count: 100),
        ),
        OpenIM.iMManager.friendshipManager.getFriendApplicationListAsApplicant(
          // dawn 2026-06-17 修复新的好友页面为空：显式分页拉取发出的好友申请。
          req: GetFriendApplicationListAsApplicantReq(offset: 0, count: 100),
        ),
      ]);

      final allList = <FriendApplicationInfo>[];
      allList
        ..addAll(list[0])
        ..addAll(list[1]);

      allList.sort((a, b) {
        if ((a.createTime ?? 0) > (b.createTime ?? 0)) {
          return -1;
        } else if ((a.createTime ?? 0) < (b.createTime ?? 0)) {
          return 1;
        }
        return 0;
      });

      var haveReadList = DataSp.getHaveReadUnHandleFriendApplication();
      haveReadList ??= <String>[];
      for (var e in list[0]) {
        var id = IMUtils.buildFriendApplicationID(e);
        if (!haveReadList.contains(id)) {
          haveReadList.add(id);
        }
      }
      DataSp.putHaveReadUnHandleFriendApplication(haveReadList);
      applicationList.assignAll(allList);
    } catch (e) {
      Logger.print('[FriendRequestsLogic] get friend applications failed: $e');
    }
  }

  bool isISendRequest(FriendApplicationInfo info) =>
      info.fromUserID == OpenIM.iMManager.userID;

  void acceptFriendApplication(FriendApplicationInfo info) =>
      AppNavigator.startProcessFriendRequests(
        applicationInfo: info,
      );

  void refuseFriendApplication(FriendApplicationInfo info) async {}
}
