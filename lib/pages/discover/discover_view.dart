import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim/pages/discover/live_page.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'discover_logic.dart';

class DiscoverPage extends StatelessWidget {
  final logic = Get.find<DiscoverLogic>();

  DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.workbench(),
      backgroundColor: Styles.c_F8F9FA,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      return SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (logic.orgController.currentOrgRoles.contains("checkin"))
              _buildCheckinCard(),
            if (logic.orgController.currentOrgRoles.contains("checkin"))
              16.verticalSpace,
            _buildFunctionGrid(),
          ],
        ),
      );
    });
  }

  Widget _buildCheckinCard() {
    return GestureDetector(
      onTap: logic.toSignIn,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4CAF50).withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: ImageRes.signin.toImage
                ..width = 28.w
                ..height = 28.h
                ..color = Colors.white,
            ),
            16.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    StrRes.checkin,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  4.verticalSpace,
                  Text(
                    StrRes.dailyCheckinGetReward,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20.r,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionGrid() {
    List<Map<String, dynamic>> functions = [
      {
        'icon': Icons.live_tv,
        'title': StrRes.meeting,
        'subtitle': StrRes.videoConferenceFunction,
        'color': Color(0xFFFF5722),
        'onTap': () {
          // IMViews.showToast(StrRes.featureInDevelopment);
          Get.to(LivePage());
        },
      },
    ];

    // 添加抽奖相关功能
    if (logic.orgController.currentOrgRoles.contains("lottery")) {
      functions.addAll([
        {
          'icon': Icons.confirmation_number,
          'title': StrRes.myTickets,
          'subtitle': StrRes.myTicketsDesc,
          'color': Color(0xFFFF9800),
          'onTap': logic.toLotteryTickets,
        },
      ]);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
      ),
      itemCount: functions.length,
      itemBuilder: (context, index) {
        final function = functions[index];
        return _buildFunctionCard(
          icon: function['icon'],
          title: function['title'],
          subtitle: function['subtitle'],
          color: function['color'],
          onTap: function['onTap'],
        );
      },
    );
  }

  Widget _buildFunctionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24.r,
                  ),
                ),
                Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C1C33),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                4.verticalSpace,
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFF8E9AB0),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
