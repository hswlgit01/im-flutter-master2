import 'package:get/get.dart';

class LuckMoneyLogLogic extends GetxController {
  @override
  void onReady() {
    _queryLuckMoneyDetail();
    super.onReady();
  }

  void _queryLuckMoneyDetail() async {
    // LoadingView.singleton.wrap(asyncFunction: () async {
    //   final list = await OpenIM.iMManager.groupManager.getGroupMembersInfo(
    //     groupID: groupInfo.groupID,
    //     userIDList: [OpenIM.iMManager.userID],
    //   );
    //   final myInfo = list.firstOrNull;
    //   if (null != myInfo) {
    //     myGroupMemberLevel.value = myInfo.roleLevel ?? 1;
    //   }
    //   await onLoad();
    // });
  }
}
