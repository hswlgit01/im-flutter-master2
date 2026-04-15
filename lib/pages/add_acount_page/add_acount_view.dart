import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';

import 'add_acount_logic.dart';

class AddAcountPageView extends StatelessWidget {
  final logic = Get.find<AddAcountPageLogic>();

  AddAcountPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.addAcountTitle,
      ),
      backgroundColor: Styles.c_F8F9FA,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              10.verticalSpace,
              // 页面说明
              Text(
                StrRes.plsCompleteInfo,
                style: Styles.ts_8E9AB0_14sp,
              ),

              4.verticalSpace,

              // 表单区域
              _buildFormContainer(),
              40.verticalSpace,
              // 提交按钮
              Obx(() => Button(
                    text: StrRes.confirm,
                    enabled: logic.enabled.value,
                    onTap: logic.submit,
                  )),

              20.verticalSpace,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormContainer() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          // 头像选择
          _buildAvatarSection(),
          24.verticalSpace,
          // 昵称输入
          _buildNicknameSection(),
          24.verticalSpace,
          // 邀请码输入
          _buildInvitationCodeSection(),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Obx(
            () => SizedBox(
              width: 80,
              height: 80,
              child: AvatarView(
                width: 80,
                height: 80,
                isCircle: true,
                onTap: logic.selectAvatar,
                file: logic.avatarFile.value,
                url: logic.avatarUrl.value.isNotEmpty
                    ? logic.avatarUrl.value
                    : logic.im.userInfo.value.faceURL,
                text: logic.im.userInfo.value.nickname,
                // showDefaultAvatar: true,
              ),
            ),
          ),
        ),
        8.verticalSpace,
        Center(
          child: Text(
            StrRes.avaterchangeAction,
            style: Styles.ts_8E9AB0_12sp,
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameSection() {
    final labelStyle =
        Styles.ts_0089FF_16sp_medium.copyWith(color: Colors.grey[700]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          StrRes.nickname,
          style: labelStyle,
        ),
        8.verticalSpace,
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Styles.c_F8F9FA,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: Styles.c_E8EAEF,
              width: 1,
            ),
          ),
          child: TextField(
            controller: logic.nicknameCtrl,
            // style: Styles.ts_0089FF_16sp,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: StrRes.plsEnterYourNickname,
              hintStyle: Styles.ts_8E9AB0_16sp,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            maxLength: 20,
            buildCounter: (context,
                {required currentLength, required isFocused, maxLength}) {
              return null; // 隐藏字符计数器
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationCodeSection() {
    final labelStyle =
        Styles.ts_0089FF_16sp_medium.copyWith(color: Colors.grey[700]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          StrRes.invitationCode,
          style: labelStyle,
        ),
        8.verticalSpace,
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Styles.c_F8F9FA,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: Styles.c_E8EAEF,
              width: 1,
            ),
          ),
          child: TextField(
            controller: logic.invitationCodeCtrl,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: sprintf(StrRes.plsEnterInvitationCode, ['']),
              hintStyle: Styles.ts_8E9AB0_16sp,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        8.verticalSpace,
        Text(
          StrRes.invitationInputPrompt,
          style: Styles.ts_8E9AB0_12sp,
        ),
      ],
    );
  }
}
