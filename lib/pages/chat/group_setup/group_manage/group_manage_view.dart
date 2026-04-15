import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'group_manage_logic.dart';

class GroupManagePage extends StatelessWidget {
  final logic = Get.find<GroupManageLogic>();

  GroupManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.groupManage,
      ),
      backgroundColor: Styles.c_F8F9FA,
      body: Obx(() {
        return Column(
          children: [
            SizedBox(
              height: 10.h,
            ),
            _buildItemView(
              text: StrRes.muteAllMember,
              showSwitchButton: true,
              switchOn: logic.groupInfo.value.status == 3,
              onChanged: (value) => logic.changeGroupMute(value),
            ),
            SizedBox(
              height: 10.h,
            ),
            if(logic.groupSetupLogic.isOwner) _buildItemView(
              text: StrRes.groupMemberPermission,
              isTopRadius: true,
              showRightArrow: true,
              value: logic.lookMemberInfoStr,
              onTap: () => logic.selectLookMemberInfoSelect()
            ),
            _buildItemView(
              text: StrRes.notAllAddMemberToBeFriend,
              showSwitchButton: true,
              switchOn: logic.groupInfo.value.applyMemberFriend == 1,
              onChanged: (value) => logic.setApplyMemberFriend(
                  logic.groupInfo.value.applyMemberFriend == 1 ? 0 : 1),
            ),
            _buildItemView(
                text: StrRes.joinGroupSet,
                value: logic.needVerificationStr,
                isBottomRadius: true,
                showRightArrow: true,
                onTap: () => logic.selectInGroupSelect()),
            SizedBox(
              height: 10.h,
            ),
            if(logic.groupSetupLogic.isOwner) _buildItemView(
              text: StrRes.transferGroupOwnerRight,
              onTap: logic.transferGroupOwnerRight,
              showRightArrow: true,
              isTopRadius: true,
              isBottomRadius: true,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildItemView({
    required String text,
    TextStyle? textStyle,
    String? value,
    bool switchOn = false,
    bool isTopRadius = false,
    bool isBottomRadius = false,
    bool showRightArrow = false,
    bool showSwitchButton = false,
    ValueChanged<bool>? onChanged,
    Function()? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: Container(
          height: 46.h,
          margin: EdgeInsets.symmetric(horizontal: 10.w),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: Styles.c_FFFFFF,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(isTopRadius ? 6.r : 0),
              topLeft: Radius.circular(isTopRadius ? 6.r : 0),
              bottomLeft: Radius.circular(isBottomRadius ? 6.r : 0),
              bottomRight: Radius.circular(isBottomRadius ? 6.r : 0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: text.toText..style = textStyle ?? Styles.ts_0C1C33_17sp,
              ),
              if (null != value)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 150.w),
                  child: value.toText
                    ..style = Styles.ts_8E9AB0_14sp
                    ..maxLines = 1
                    ..overflow = TextOverflow.ellipsis,
                ),
              if (showSwitchButton)
                CupertinoSwitch(
                  value: switchOn,
                  activeColor: Styles.c_0089FF,
                  onChanged: onChanged,
                ),
              if (showRightArrow)
                ImageRes.rightArrow.toImage
                  ..width = 24.w
                  ..height = 24.h,
            ],
          ),
        ),
      );
}
