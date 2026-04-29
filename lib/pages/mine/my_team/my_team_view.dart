import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'my_team_logic.dart';

class MyTeamPage extends StatelessWidget {
  MyTeamPage({super.key});

  final logic = Get.find<MyTeamLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles.c_F8F9FA,
      appBar: TitleBar.back(title: '我的团队'),
      body: SafeArea(
        child: Obx(
          () => logic.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: logic.initializeData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildTeamStatistics(),
                        SizedBox(height: 8.h),
                        _buildInvitationCodeSection(),
                        SizedBox(height: 8.h),
                        _buildDownloadSection(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // 团队统计信息
  Widget _buildTeamStatistics() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Obx(() {
        final teamData = logic.teamInfo.value;
        final teamSize = teamData?.teamSize ?? 0;
        final directDownlineCount = teamData?.directDownlineCount ?? 0;

        return Row(
          children: [
            // 团队人数
            Expanded(
              child: Column(
                children: [
                  Text('我的团队', style: Styles.ts_8E9AB0_14sp),
                  SizedBox(height: 8.h),
                  Text(
                    '$teamSize',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: Styles.c_0089FF,
                    ),
                  ),
                ],
              ),
            ),
            // 分隔线
            Container(
              width: 1.w,
              height: 30.h,
              color: Styles.c_E8EAEF,
              margin: EdgeInsets.symmetric(horizontal: 8.w),
            ),
            // 直推人数
            Expanded(
              child: Column(
                children: [
                  Text('我的直推', style: Styles.ts_8E9AB0_14sp),
                  SizedBox(height: 8.h),
                  Text(
                    '$directDownlineCount',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: Styles.c_0089FF,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  // 邀请码部分
  Widget _buildInvitationCodeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('邀请码', style: Styles.ts_8E9AB0_14sp),
          SizedBox(height: 12.h),
          Obx(() {
            final teamData = logic.teamInfo.value;
            final invitationCode = teamData?.invitationCode ?? '';

            return InkWell(
              onTap: logic.copyInvitationCode,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      invitationCode,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                        color: Styles.c_0089FF,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Icon(
                    Icons.content_copy,
                    color: Styles.c_0089FF,
                    size: 18.sp,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 下载部分
  Widget _buildDownloadSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('下载链接', style: Styles.ts_8E9AB0_14sp),
          SizedBox(height: 16.h),
          // 二维码
          Center(
            child: Obx(() {
              final url = logic.downloadUrl.value;
              if (logic.isDownloadUrlLoading.value) {
                return Container(
                  width: 180.w,
                  height: 180.w,
                  decoration: BoxDecoration(
                    color: Styles.c_F2F4F7,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.w,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
                      ),
                      SizedBox(height: 8.h),
                      Text('加载中...', style: Styles.ts_8E9AB0_14sp),
                    ],
                  ),
                );
              }
              if (url.isEmpty) {
                return Container(
                  width: 180.w,
                  height: 180.w,
                  decoration: BoxDecoration(
                    color: Styles.c_F2F4F7,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.link_off,
                        size: 32.sp,
                        color: Styles.c_8E9AB0,
                      ),
                      SizedBox(height: 8.h),
                      Text('暂无下载链接', style: Styles.ts_8E9AB0_14sp),
                    ],
                  ),
                );
              }
              return QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 180.w,
                backgroundColor: Styles.c_FFFFFF,
                padding: EdgeInsets.all(8.r),
              );
            }),
          ),
          SizedBox(height: 16.h),
          // 下载链接
          SizedBox(height: 8.h),
          Obx(() => Container(
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: Styles.c_F2F4F7,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.link,
                          size: 16.sp,
                          color: Styles.c_8E9AB0,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          '下载地址',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Styles.c_0C1C33,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: logic.copyDownloadUrl,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: Styles.c_0089FF,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.content_copy,
                                  color: Styles.c_FFFFFF,
                                  size: 14.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '复制',
                                  style: Styles.ts_FFFFFF_14sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    // 链接内容区域
                    logic.downloadUrl.value.isNotEmpty
                        ? Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: Styles.c_FFFFFF,
                              borderRadius: BorderRadius.circular(4.r),
                              border: Border.all(color: Styles.c_E8EAEF),
                            ),
                            child: Text(
                              logic.downloadUrl.value,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Styles.c_0089FF,
                                height: 1.4,
                              ),
                              softWrap: true,
                              textAlign: TextAlign.left,
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: Styles.c_FFFFFF,
                              borderRadius: BorderRadius.circular(4.r),
                              border: Border.all(color: Styles.c_E8EAEF),
                            ),
                            child: Text(
                              '暂无下载链接，请等待配置',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Styles.c_8E9AB0,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
