import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
      logic.onPageEnter();
    }
  }

  @override
  void didChangeDependencies() {
    logic.onPageEnter();
    super.didChangeDependencies();
  }

  // 实名认证状态文案
  String get _realnameText {
    final status = logic.identityInfo?.status ?? 0;
    final realName = logic.identityInfo?.realName;
    switch (status) {
      case 1:
        return '审核中';
      case 2:
        if (realName != null && realName.isNotEmpty) {
          return '已认证(${realName.substring(0, 1)}**)';
        }
        return '已认证';
      case 3:
        return '审核未通过';
      default:
        return '未实名认证';
    }
  }

  @override
  Widget build(BuildContext context) {
    // dawn 2026-06-26 "我的"页按设计稿改版：头部(头像+昵称+点击实名+性别/实名chip)、
    // 签到卡、邀请区(邀请码/二维码/我的团队)、常用服务(收款/余额/密码/通用/关于)、退出登录。
    return Scaffold(
      backgroundColor: Styles.c_F8F9FA,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Obx(() => _buildHeader()),
            12.verticalSpace,
            _buildCheckinCard(),
            12.verticalSpace,
            // 邀请区
            _card(children: [
              Obx(() => _buildRow(
                    icon: ImageRes.mineInviteCode,
                    label: '心享邀请码',
                    valueText: logic.invitationCode,
                    showArrow: false,
                    onTap: logic.copyInvitationCode,
                  )),
              _divider(),
              _buildRow(
                icon: ImageRes.mineInviteQr,
                label: '邀请二维码',
                onTap: logic.toQrCodePage,
              ),
              _divider(),
              _buildRow(
                icon: ImageRes.mineTeam,
                label: '我的团队',
                onTap: logic.viewMyTeam,
              ),
            ]),
            12.verticalSpace,
            // 常用服务
            _card(children: [
              _buildSectionHeader(),
              _divider(),
              _buildRow(
                icon: ImageRes.minePayment,
                label: StrRes.paymentMethod,
                onTap: logic.viewPaymentMethod,
              ),
              _divider(),
              _buildBalanceRow(),
              _divider(),
              _buildRow(
                icon: ImageRes.minePassword,
                label: StrRes.changePassword,
                onTap: logic.viewPasswordSetup,
              ),
              _divider(),
              _buildRow(
                icon: ImageRes.mineGeneral,
                label: StrRes.languageSetup,
                onTap: logic.viewGeneral,
              ),
              _divider(),
              _buildRow(
                icon: ImageRes.mineAbout,
                label: StrRes.aboutUs,
                onTap: logic.aboutUs,
              ),
            ]),
            12.verticalSpace,
            // 退出登录
            _card(children: [
              InkWell(
                onTap: logic.logout,
                child: Container(
                  height: 52.h,
                  alignment: Alignment.center,
                  child: Text(
                    StrRes.logout,
                    style: TextStyle(
                      color: Styles.c_FF381F,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ]),
            24.verticalSpace,
          ],
        ),
      ),
    );
  }

  // 头部：头像 + 昵称 + 点击实名 + 性别/实名 chip
  Widget _buildHeader() {
    return Container(
      width: 1.sw,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCFE6FF), Color(0xFFF8F9FA)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 10.h,
            child: Opacity(
              opacity: 0.25,
              child: ImageRes.mineHeaderLogo.toImage
                ..width = 120.w
                ..height = 120.w,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 60.h, 16.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // dawn 2026-06-30 修复"我的信息"点不进去：头像+昵称区域接入 viewMyInfo。
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: logic.viewMyInfo,
                      child: AvatarView(
                        url: logic.imLogic.userInfo.value.faceURL,
                        text: logic.imLogic.userInfo.value.nickname,
                        width: 64.w,
                        height: 64.w,
                        textStyle: Styles.ts_FFFFFF_17sp,
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: logic.viewMyInfo,
                        child: Text(
                          logic.imLogic.userInfo.value.nickname ?? '',
                          style: Styles.ts_0C1C33_17sp_medium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: logic.openIdentityVerifyPage,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('点击实名', style: Styles.ts_8E9AB0_14sp),
                          ImageRes.mineArrow.toImage
                            ..width = 16.w
                            ..height = 16.w,
                        ],
                      ),
                    ),
                  ],
                ),
                12.verticalSpace,
                Row(
                  children: [
                    _chip(
                      icon: ImageRes.mineGender,
                      text: logic.genderText,
                      onTap: null,
                    ),
                    10.horizontalSpace,
                    _chip(
                      icon: ImageRes.mineRealname,
                      text: _realnameText,
                      onTap: logic.openIdentityVerifyPage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
      {required String icon, required String text, Function()? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon.toImage
              ..width = 16.w
              ..height = 16.w,
            6.horizontalSpace,
            Text(text, style: Styles.ts_0C1C33_14sp),
          ],
        ),
      ),
    );
  }

  // 签到卡(浅蓝渐变独立卡)
  Widget _buildCheckinCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDCEBFF), Color(0xFFEAF3FF)],
            ),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8.r),
            onTap: logic.toSignIn,
            child: Container(
              height: 56.h,
              padding: EdgeInsets.only(left: 12.w, right: 16.w),
              child: Row(
                children: [
                  ImageRes.mineCheckin.toImage
                    ..width = 24.w
                    ..height = 24.w,
                  11.horizontalSpace,
                  Text(StrRes.checkin, style: Styles.ts_0C1C33_17sp_medium),
                  const Spacer(),
                  Text('前往签到', style: Styles.ts_8E9AB0_14sp),
                  ImageRes.mineArrow.toImage
                    ..width = 18.w
                    ..height = 18.w,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Padding(
        padding: EdgeInsets.only(left: 47.w),
        child: Divider(height: 1, color: const Color(0xFFF0F0F0)),
      );

  // 常用服务分区标题
  Widget _buildSectionHeader() {
    return Container(
      height: 50.h,
      padding: EdgeInsets.only(left: 12.w, right: 16.w),
      child: Row(
        children: [
          ImageRes.mineServices.toImage
            ..width = 22.w
            ..height = 22.w,
          11.horizontalSpace,
          Text('常用服务', style: Styles.ts_0C1C33_17sp_medium),
          const Spacer(),
          Text('心有所享 沟通无界', style: Styles.ts_8E9AB0_14sp),
        ],
      ),
    );
  }

  // 余额行(带"点击提现")
  Widget _buildBalanceRow() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: logic.viewWalletWithdraw,
        child: Container(
          height: 56.h,
          padding: EdgeInsets.only(left: 12.w, right: 16.w),
          child: Row(
            children: [
              ImageRes.mineBalance.toImage
                ..width = 24.w
                ..height = 24.w,
              11.horizontalSpace,
              Text('余额', style: Styles.ts_0C1C33_17sp),
              const Spacer(),
              Obx(() => Text('${logic.balanceText}元',
                  style: Styles.ts_8E9AB0_14sp.copyWith(color: Styles.c_0089FF))),
              8.horizontalSpace,
              Text('点击提现',
                  style: Styles.ts_0089FF_14sp
                      .copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // 通用行控件
  Widget _buildRow({
    required String icon,
    required String label,
    String? valueText,
    bool showArrow = true,
    Function()? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56.h,
          padding: EdgeInsets.only(left: 12.w, right: 16.w),
          child: Row(
            children: [
              icon.toImage
                ..width = 24.w
                ..height = 24.w,
              11.horizontalSpace,
              Text(label, style: Styles.ts_0C1C33_17sp),
              const Spacer(),
              if (valueText != null && valueText.isNotEmpty)
                Flexible(
                  child: Text(
                    valueText,
                    style: Styles.ts_8E9AB0_14sp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (showArrow)
                ImageRes.mineArrow.toImage
                  ..width = 18.w
                  ..height = 18.w,
            ],
          ),
        ),
      ),
    );
  }
}
