import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim/pages/discover/live_page.dart';

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
            _buildItemView(
              icon: ImageRes.wallet,
              label: StrRes.wallet,
              onTap: logic.viewWallet,
              isTopRadius: true,
            ),
            _buildItemView(
              icon: ImageRes.gift,
              label: StrRes.checkin,
              onTap: logic.toSignIn,  // 使用与发现页相同的跳转方法
              isTopRadius: true,
            ),  
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              child: Ink(
                decoration: BoxDecoration(
                  color: Styles.c_FFFFFF,
                  borderRadius: BorderRadius.circular(0),
                ),
                child: InkWell(
                  onTap: () {
                    Get.to(LivePage());
                  },
                  child: Container(
                    height: 56.h,
                    padding: EdgeInsets.only(left: 12.w, right: 16.w),
                    child: Row(
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          size: 24.w,
                          color: Color(0xFF333333),
                        ),
                        11.horizontalSpace,
                        Text(
                          StrRes.meeting,
                          style: Styles.ts_0C1C33_17sp,
                        ),
                        const Spacer(),
                        ImageRes.rightArrow.toImage
                          ..width = 24.w
                          ..height = 24.h,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildItemView(
              icon: ImageRes.transfer,
              label: StrRes.paymentMethod,
              onTap: logic.viewPaymentMethod,
            ),
            _buildItemView(
              icon: ImageRes.myInfo,
              label: StrRes.myInfo,
              onTap: logic.viewMyInfo,
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              child: Ink(
                decoration: BoxDecoration(
                  color: Styles.c_FFFFFF,
                  borderRadius: BorderRadius.circular(0),
                ),
                child: InkWell(
                  onTap: logic.viewMyTeam,
                  child: Container(
                    height: 56.h,
                    padding: EdgeInsets.only(left: 12.w, right: 16.w),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 24.w,
                          color: Color(0xFF333333),
                        ),
                        11.horizontalSpace,
                        Text(
                          '我的团队',
                          style: Styles.ts_0C1C33_17sp,
                        ),
                        const Spacer(),
                        ImageRes.rightArrow.toImage
                          ..width = 24.w
                          ..height = 24.h,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildIdentityVerifyItem(),
            _buildItemView(
              icon: ImageRes.accountSetup,
              label: StrRes.accountSetup,
              onTap: logic.accountSetup,
            ),
            
            _buildItemView(
              icon: ImageRes.aboutUs,
              label: StrRes.aboutUs,
              onTap: logic.aboutUs,
            ),
            _buildItemView(
              icon: ImageRes.logout,
              label: StrRes.logout,
              onTap: logic.logout,
              isBottomRadius: true,
            ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  (logic.imLogic.userInfo.value.nickname ?? '').toText
                    ..style = Styles.ts_0C1C33_17sp_medium,
                  4.verticalSpace,
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: logic.copyID,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        (logic.imLogic.userInfo.value.userID ?? '').toText
                          ..style = Styles.ts_8E9AB0_14sp,
                        ImageRes.mineCopy.toImage
                          ..width = 16.w
                          ..height = 16.h,
                      ],
                    ),
                  ),
                ],
              ),
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
                    StrRes.identityVerify ?? '身份认证',
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

  Widget _buildItemView({
    required String icon,
    required String label,
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
                  icon.toImage
                    ..width = 24.w
                    ..height = 24.h,
                  11.horizontalSpace,
                  label.toText..style = Styles.ts_0C1C33_17sp,
                  const Spacer(),
                  ImageRes.rightArrow.toImage
                    ..width = 24.w
                    ..height = 24.h,
                ],
              ),
            ),
          ),
        ),
      );
}
