import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../../../core/controller/im_controller.dart';
import 'my_info_logic.dart';

class MyInfoPage extends StatelessWidget {
  final logic = Get.find<MyInfoLogic>();
  final imLogic = Get.find<IMController>();

  MyInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.myInfo,
      ),
      backgroundColor: Styles.c_F8F9FA,
      body: Obx(() => SingleChildScrollView(
            child: Column(
              children: [
                10.verticalSpace,
                _buildCornerBgView(
                  children: [
                    _buildItemView(
                      label: StrRes.avatar,
                      isAvatar: true,
                      value: imLogic.userInfo.value.nickname,
                      url: imLogic.userInfo.value.faceURL,
                      onTap: logic.openPhotoSheet,
                    ),
                    _buildItemView(
                      label: StrRes.name,
                      value: imLogic.userInfo.value.nickname,
                      showRightArrow: logic.orgController.currentOrgRoles.contains("modify_nickname"),
                      onTap: logic.editMyName,
                    ),
                    _buildItemView(
                      label: StrRes.gender,
                      value: imLogic.userInfo.value.isMale ? StrRes.man : StrRes.woman,
                      onTap: logic.selectGender,
                    ),
                    _buildItemView(
                      label: StrRes.birthDay,
                      value: DateUtil.formatDateMs(
                        imLogic.userInfo.value.birth ?? 0,
                        format: IMUtils.getTimeFormat1(),
                      ),
                      onTap: logic.openDatePicker,
                    ),
                    _buildItemView(
                      label: StrRes.points,
                      value: logic.userInfo.value?.points?.toString() ?? '0',
                      showRightArrow: false,
                    ),
                    // 身份认证项
                    //_buildIdentityVerifyItem(),
                  ],
                ),
                10.verticalSpace,
                _buildCornerBgView(
                  children: [
                    _buildItemView(
                      label: StrRes.account,
                      value: logic.userInfo.value?.account ?? '',
                      onTap: () => logic.copyAccount(),
                    ),
                    _buildItemView(
                      label: StrRes.invitationCode,
                      value: logic.userInfo.value?.invitationCode ?? '',
                      onTap: () => logic.copyInvitationCode(),
                    ),
                  ],
                ),
              ],
            ),
          )),
    );
  }

  // 构建身份认证项目
  Widget _buildIdentityVerifyItem() {
    // 从Logic获取身份信息
    final identityInfo = logic.identityInfo;
    final status = identityInfo?.status ?? 0;
    final realName = identityInfo?.realName;
    final isRejected = status == 3;

    String statusText = '';
    Color statusColor = Colors.grey;

    // 使用国际化字符串
    switch (status) {
      case 0:
        statusText = StrRes.verifyStatusPending ?? '待认证';
        statusColor = Colors.grey;
        break;
      case 1:
        statusText = StrRes.verifyStatusReviewing ?? '审核中';
        statusColor = Colors.orange;
        break;
      case 2:
        if (realName != null && realName.isNotEmpty) {
          final lastName = realName.substring(0, 1);
          statusText = StrRes.verifyStatusApproved+'($lastName**)';
        } else {
          statusText = StrRes.verifyStatusApproved ?? '已认证';
        }
        statusColor = Colors.green;
        break;
      case 3:
        statusText = StrRes.verifyStatusRejected ?? '审核未通过';
        statusColor = Colors.red;
        break;
    }

    // 所有状态都显示箭头
    final shouldShowArrow = true;

    // 所有状态都允许进入认证页面查看详情
    final onTap = logic.openIdentityVerifyPage;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: shouldShowArrow ? onTap : null,
      child: Container(
        height: 46.h,
        padding: isRejected ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h) : EdgeInsets.zero,
        decoration: isRejected
          ? BoxDecoration(
              color: Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(
                color: Color(0xFFFFCCC7),
                width: 1,
              ),
            )
          : null,
        child: Row(
          children: [
            if (isRejected)
              Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: Icon(
                  Icons.error_outline,
                  size: 18.w,
                  color: Colors.red,
                ),
              ),
            Text(
              StrRes.identityVerify ?? '身份认证',
              style: Styles.ts_0C1C33_17sp,
            ),
            const Spacer(),
            Expanded(
              flex: 3,
              child: Text(
                statusText,
                style: Styles.ts_0C1C33_17sp.copyWith(color: statusColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            if (shouldShowArrow)
              ImageRes.rightArrow.toImage
                ..width = 24.w
                ..height = 24.h,
          ],
        ),
      ),
    );
  }

  // 审核中对话框
  void _showReviewingDialog(IdentityVerifyInfo? info) {
    Get.dialog(
      AlertDialog(
        title: Text(StrRes.reviewingStatus ?? '审核状态'),
        content: Text(StrRes.reviewingMsg ?? '您的身份认证正在审核中，请耐心等待...'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(StrRes.confirm ?? '确定'),
          ),
        ],
      ),
    );
  }

  // 审核拒绝对话框
  void _showRejectedDialog(IdentityVerifyInfo? info) {
    final rejectReason = info?.rejectReason;
    final hasReason = rejectReason != null && rejectReason.isNotEmpty;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题带错误图标
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 24.w,
                    color: Colors.red,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '身份认证未通过',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // 拒绝原因
              if (hasReason) ...[
                Text(
                  '拒绝原因：',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: Color(0xFFFFCCC7),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    rejectReason,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Color(0xFF0C1C33),
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: Color(0xFFFFCCC7),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '您的身份认证申请未通过审核，请重新提交。',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Color(0xFF0C1C33),
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
              ],

              // 按钮行
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        side: BorderSide(color: Color(0xFF0089FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                      child: Text(
                        StrRes.cancel ?? '取消',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Color(0xFF0089FF),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        logic.openIdentityVerifyPage();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0089FF),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                      child: Text(
                        '重新提交',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isDismissible: true,
      enableDrag: true,
    );
  }

  // 显示已认证信息
  void _showVerifiedInfo(IdentityVerifyInfo? info) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                StrRes.verifyInfo ?? '身份认证信息',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            _buildInfoItem(
              StrRes.verifyStatus ?? '认证状态', 
              StrRes.verifyStatusApproved ?? '已认证'
            ),
            _buildInfoItem(
              StrRes.realName ?? '真实姓名', 
              info?.realName ?? ''
            ),
            _buildInfoItem(
              StrRes.verifyTime ?? '认证时间',
              DateUtil.formatDateMs(
                info?.verifyTime ?? 0,
                format: 'yyyy-MM-dd HH:mm',
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                child: Text(StrRes.confirm ?? '确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Text(
            '$label：',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerBgView({required List<Widget> children}) => Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        margin: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(6.r),
            topRight: Radius.circular(6.r),
            bottomLeft: Radius.circular(6.r),
            bottomRight: Radius.circular(6.r),
          ),
        ),
        child: Column(children: children),
      );

  Widget _buildItemView({
    required String label,
    String? value,
    String? url,
    bool isAvatar = false,
    bool showRightArrow = true,
    Function()? onTap,
  }) =>
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: showRightArrow ? onTap : null,
        child: SizedBox(
          height: 46.h,
          child: Row(
            children: [
              Text(label, style: Styles.ts_0C1C33_17sp),
              const Spacer(),
              if (isAvatar)
                AvatarView(
                  width: 32.w,
                  height: 32.h,
                  url: url,
                  text: value,
                  textStyle: Styles.ts_FFFFFF_10sp,
                )
              else
                Expanded(
                  flex: 3,
                  child: Text(
                    IMUtils.emptyStrToNull(value) ?? '',
                    style: Styles.ts_0C1C33_17sp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
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