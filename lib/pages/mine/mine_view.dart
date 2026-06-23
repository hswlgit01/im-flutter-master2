import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'mine_logic.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> with WidgetsBindingObserver {
  final logic = Get.find<MineLogic>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 当应用从后台恢复时，调用刷新方法
      logic.onPageEnter();
    }
  }

  @override
  void didChangeDependencies() {
    // 当依赖关系变化时，例如从其他页面返回时可能会触发
    logic.onPageEnter();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // dawn 2026-06-23 我的页改版：照设计稿(性别/实名/签到/邀请码/二维码/团队/收款/余额/密码/通用/关于/退出)。
    return Scaffold(
      backgroundColor: Styles.c_F8F9FA,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 138.h,
                  width: 1.sw,
                  color: Styles.c_0089FF,
                  child: ImageRes.mineHeaderBg.toImage,
                ),
                Obx(() => _buildMyInfoView()),
              ],
            ),
            10.verticalSpace,
            // 卡片一：性别 / 实名认证 / 签到
            _buildRow(
              iconData: Icons.wc_outlined,
              label: StrRes.gender,
              valueWidget: Obx(() => Text(
                    logic.genderText,
                    style: Styles.ts_8E9AB0_14sp,
                  )),
              showArrow: false,
              isTopRadius: true,
            ),
            _buildIdentityVerifyItem(),
            _buildRow(
              iconData: Icons.event_available_outlined,
              label: StrRes.checkin,
              onTap: logic.toSignIn,
              isBottomRadius: true,
            ),
            10.verticalSpace,
            // 卡片二：心享邀请码 / 邀请二维码
            _buildRow(
              iconData: Icons.confirmation_number_outlined,
              label: '心享邀请码',
              valueWidget: Obx(() => Text(
                    logic.invitationCode,
                    style: Styles.ts_8E9AB0_14sp,
                  )),
              showArrow: false,
              onTap: logic.copyInvitationCode,
              isTopRadius: true,
            ),
            _buildRow(
              iconData: Icons.qr_code_2_outlined,
              label: '邀请二维码',
              onTap: logic.toQrCodePage,
              isBottomRadius: true,
            ),
            10.verticalSpace,
            // 卡片三：我的团队 / 收款方式 / 余额
            _buildRow(
              iconData: Icons.people_outline,
              label: '我的团队',
              onTap: logic.viewMyTeam,
              isTopRadius: true,
            ),
            _buildRow(
              iconData: Icons.account_balance_wallet_outlined,
              label: StrRes.paymentMethod,
              onTap: logic.viewPaymentMethod,
            ),
            _buildRow(
              iconData: Icons.savings_outlined,
              label: '余额',
              valueWidget: Obx(() => Text(
                    '${logic.balanceText}元  点击提现',
                    style: Styles.ts_8E9AB0_14sp.copyWith(color: Styles.c_0089FF),
                  )),
              onTap: logic.viewWalletWithdraw,
              isBottomRadius: true,
            ),
            10.verticalSpace,
            // 卡片四：密码设置 / 通用 / 关于我们
            _buildRow(
              iconData: Icons.lock_outline,
              label: StrRes.changePassword,
              onTap: logic.viewPasswordSetup,
              isTopRadius: true,
            ),
            _buildRow(
              iconData: Icons.settings_outlined,
              label: StrRes.languageSetup,
              onTap: logic.viewGeneral,
            ),
            _buildRow(
              iconData: Icons.info_outline,
              label: StrRes.aboutUs,
              onTap: logic.aboutUs,
              isBottomRadius: true,
            ),
            10.verticalSpace,
            // 卡片五：退出登录
            _buildRow(
              iconData: Icons.logout_outlined,
              label: StrRes.logout,
              onTap: logic.logout,
              showArrow: false,
              isTopRadius: true,
              isBottomRadius: true,
            ),
            20.verticalSpace,
          ],
        ),
      ),
    );
  }

  Widget _buildMyInfoView() => Container(
        height: 98.h,
        margin: EdgeInsets.only(left: 16.w, right: 16.w, top: 90.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          children: [
            AvatarView(
              url: logic.imLogic.userInfo.value.faceURL,
              text: logic.imLogic.userInfo.value.nickname,
              width: 48.w,
              height: 48.h,
              textStyle: Styles.ts_FFFFFF_14sp,
            ),
            10.horizontalSpace,
            Expanded(
              child: (logic.imLogic.userInfo.value.nickname ?? '').toText
                ..style = Styles.ts_0C1C33_17sp_medium,
            ),
            GestureDetector(
              onTap: () => logic.toQrCodePage(),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  ImageRes.mineQr.toImage..width = 20.w,
                  ImageRes.rightArrow.toImage..width = 26.w
                ],
              ),
            ),
          ],
        ),
      );

  // dawn 2026-06-23 我的页改版统一行控件：支持图标/右侧值/箭头/圆角。
  Widget _buildRow({
    IconData? iconData,
    required String label,
    String? value,
    Widget? valueWidget,
    bool showArrow = true,
    bool isTopRadius = false,
    bool isBottomRadius = false,
    Function()? onTap,
  }) =>
      Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        child: Ink(
          decoration: BoxDecoration(
            color: Styles.c_FFFFFF,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(isTopRadius ? 6.r : 0),
              topLeft: Radius.circular(isTopRadius ? 6.r : 0),
              bottomLeft: Radius.circular(isBottomRadius ? 6.r : 0),
              bottomRight: Radius.circular(isBottomRadius ? 6.r : 0),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 56.h,
              padding: EdgeInsets.only(left: 12.w, right: 16.w),
              child: Row(
                children: [
                  if (iconData != null) ...[
                    Icon(iconData, size: 24.w, color: const Color(0xFF333333)),
                    11.horizontalSpace,
                  ],
                  Text(label, style: Styles.ts_0C1C33_17sp),
                  const Spacer(),
                  if (valueWidget != null) valueWidget,
                  if (value != null && valueWidget == null)
                    Text(value, style: Styles.ts_8E9AB0_14sp),
                  if (showArrow)
                    ImageRes.rightArrow.toImage
                      ..width = 24.w
                      ..height = 24.h,
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildIdentityVerifyItem() {
    return Obx(() {
      final identityInfo = logic.identityInfo;
      final status = identityInfo?.status ?? 0;
      final realName = identityInfo?.realName;
      final isRejected = status == 3;
      final isReviewing = status == 1;

      String statusText = '';
      Color statusColor = Colors.grey;

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
            statusText = StrRes.verifyStatusApproved + '($lastName**)';
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

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        child: Ink(
          decoration: BoxDecoration(
            color: isRejected ? Color(0xFFFFF1F0) : Styles.c_FFFFFF,
            borderRadius: BorderRadius.circular(0), // Middle item
          ),
          child: InkWell(
            onTap: logic.openIdentityVerifyPage,
            child: Container(
              height: 56.h,
              padding: EdgeInsets.only(left: 12.w, right: 16.w),
              child: Row(
                children: [
                  // 使用Icon代替ImageRes
                  Icon(
                    Icons.verified_user_outlined,
                    size: 24.w,
                    color: isRejected ? Colors.red : Color(0xFF333333),
                  ),
                  11.horizontalSpace,
                  Text(
                    '实名认证',
                    style: Styles.ts_0C1C33_17sp,
                  ),
                  const Spacer(),
                  // 审核中状态添加刷新按钮
                  if (isReviewing)
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 20.w,
                        color: Colors.orange,
                      ),
                      onPressed: () async {
                        // 显示刷新指示器
                        EasyLoading.show(status: '刷新中...');
                        // 强制刷新状态
                        await logic.forceRefreshIdentityInfo();
                        EasyLoading.dismiss();
                      },
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      splashRadius: 20.r,
                    ),
                  SizedBox(width: 8.w),
                  Text(
                    statusText,
                    style: Styles.ts_0C1C33_17sp.copyWith(color: statusColor),
                  ),
                  ImageRes.rightArrow.toImage
                    ..width = 24.w
                    ..height = 24.h,
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
