import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim_common/openim_common.dart';
import './logic.dart';

class PersonalSpaceView extends StatefulWidget {
  @override
  _PersonalSpaceViewState createState() => _PersonalSpaceViewState();
}

class _PersonalSpaceViewState extends State<PersonalSpaceView> {
  final logic = Get.find<PersonalSpaceLogic>();
  final im = Get.find<IMController>();

  @override
  initState() {
    super.initState();
    logic.onViewOpened();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Row(
        children: [
          Container(
            padding: EdgeInsets.only(top: 24.h),
            color: Styles.c_F0F2F6,
            width: 110.w,
            child: SafeArea(
                child: Column(
              children: [
                ...List.generate(logic.orgController.orgList.length, (index) {
                  final org = logic.orgController.orgList[index];
                  final isChecked = logic.orgController.currentOrgId.value ==
                      org.organizationId;
                  return GestureDetector(
                    onTap: () => logic.changeOrg(org.organizationId!),
                    child: Container(
                        padding: EdgeInsets.only(bottom: 18.h),
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Positioned(
                                left: 0,
                                top: 0,
                                child: Container(
                                    width: 4.w,
                                    height: 55.w,
                                    decoration: BoxDecoration(
                                      color: isChecked
                                          ? Styles.c_0089FF
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(20.w),
                                        bottomRight: Radius.circular(20.w),
                                      ),
                                    ))),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.only(left: 4.w),
                              child: Column(
                                children: [
                                  Column(
                                    children: [
                                      AvatarView(
                                        width: 55.w,
                                        height: 55.w,
                                        url: org.organization?.logo ?? '',
                                        text: org.organization?.name ?? '',
                                      ),
                                      4.verticalSpace,
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.w),
                                        child: Text(
                                          org.organization?.name ?? '',
                                          style: TextStyle(
                                            color: Styles.c_0C1C33,
                                            fontSize: 12.sp,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        )),
                  );
                }),
                GestureDetector(
                  onTap: () => logic.addAcount(),
                  child: Container(
                    padding: EdgeInsets.only(left: 4.w),
                    child: Column(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 55.w,
                              height: 55.w,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6.r)),
                              child: Icon(
                                Icons.add,
                                color: Styles.c_0089FF,
                                size: 28.sp,
                              ),
                            ),
                            // 4.verticalSpace,
                            // Text(
                            //   "登录更多账号",
                            //   style: TextStyle(
                            //     color: Styles.c_0C1C33,
                            //     fontSize: 12.sp,
                            //   ),
                            // ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            )),
          ),
          Expanded(
            child: SafeArea(
                child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AvatarView(
                              width: 70.w,
                              height: 70.w,
                              text: im.userInfo.value.nickname,
                              url: im.userInfo.value.faceURL,
                              isCircle: true,
                            ),
                          ],
                        ),
                        16.verticalSpace,
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => logic.toQrCodePage(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  im.userInfo.value.nickname ?? '',
                                  style: TextStyle(
                                    fontSize: 22.sp,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                children: [
                                  ImageRes.mineQr.toImage..width = 20.w,
                                  ImageRes.rightArrow.toImage..width = 24.w
                                ],
                              )
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              logic.orgController.currentOrg.organization
                                      ?.name ??
                                  '',
                              style: TextStyle(
                                color: Styles.c_8E9AB0,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                        // Row(
                        //   children: [
                        //     GestureDetector(
                        //       behavior: HitTestBehavior.translucent,
                        //       onTap: logic.copyID,
                        //       child: Row(
                        //         mainAxisSize: MainAxisSize.min,
                        //         children: [
                        //           Container(
                        //             width: 100.w, // 设置一个合适的宽度
                        //             child: Text(
                        //               logic.userInfo.value?.account ?? '',
                        //               style: Styles.ts_8E9AB0_12sp,
                        //               overflow: TextOverflow.ellipsis,
                        //               maxLines: 2,
                        //             ),
                        //           ),
                        //           // ImageRes.mineCopy.toImage
                        //           //   ..width = 16.w
                        //           //   ..height = 16.h,
                        //         ],
                        //       ),
                        //     )
                        //   ],
                        // ),
                      ],
                    ),
                  ),
                  20.verticalSpace,
                  _buildItemView(
                    icon: ImageRes.myInfo,
                    label: StrRes.myInfo,
                    onTap: logic.viewMyInfo,
                  ),
                  _buildItemView(
                    icon: ImageRes.wallet,
                    label: StrRes.wallet,
                    onTap: logic.viewWallet,
                    isTopRadius: true,
                  ),
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
            )),
          )
        ],
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
            borderRadius: BorderRadius.all(Radius.circular(6.r)),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              height: 56.h,
              child: Row(
                children: [
                  icon.toImage
                    ..width = 24.w
                    ..height = 24.h,
                  11.horizontalSpace,
                  label.toText..style = Styles.ts_0C1C33_17sp,
                ],
              ),
            ),
          ),
        ),
      );
}
