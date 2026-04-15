import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

import 'group_member_list_logic.dart';

class SelectedMemberListPage extends StatelessWidget {
  SelectedMemberListPage({super.key});
  final logic =
      Get.find<LuckMoneyGroupMemberListLogic>(tag: 'luck_money_select');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: StrRes.groupMember),
      backgroundColor: Styles.c_F8F9FA,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            color: Styles.c_FFFFFF,
            child: SearchBox(
              controller: logic.searchCtrl,
              focusNode: logic.focusNode,
              hintText: StrRes.search,
              onCleared: logic.clearSearch,
              enabled: true,
            ),
          ),
          Obx(() => Flexible(
                child: SmartRefresher(
                  controller: logic.controller,
                  onLoading: logic.onLoad,
                  enablePullDown: false,
                  enablePullUp: true,
                  header: IMViews.buildHeader(),
                  footer: IMViews.buildFooter(),
                  child: ListView.builder(
                    itemCount: logic.filteredMemberList.value.length,
                    itemBuilder: (_, index) =>
                        Obx(() => _buildItemView(logic.filteredMemberList[index])),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildItemView(GroupMembersInfo membersInfo) {
    if (membersInfo.userID == logic.imLogic.userInfo.value.userID) {
      return SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => logic.clickMember(membersInfo),
      child: Container(
        height: 64.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        color: Styles.c_FFFFFF,
        child: Row(
          children: [
            AvatarView(
              url: membersInfo.faceURL,
              text: membersInfo.nickname,
            ),
            10.horizontalSpace,
            Expanded(
              child: (membersInfo.nickname ?? '').toText
                ..style = Styles.ts_0C1C33_17sp
                ..maxLines = 1
                ..overflow = TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
