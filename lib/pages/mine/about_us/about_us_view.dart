import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'about_us_logic.dart';

class AboutUsPage extends StatelessWidget {
  final logic = Get.find<AboutUsLogic>();

  AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: StrRes.aboutUs),
      backgroundColor: Styles.c_F8F9FA,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(6.r),
            ),
            margin: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 10.h,
            ),
            child: Column(
              children: [
                23.verticalSpace,
                ImageRes.splashLogo.toImage
                  // dawn 2026-06-30 统一为方形 app 图标，按比例缩放避免拉伸。
                  ..width = 78.w
                  ..height = 78.w
                  ..fit = BoxFit.contain,
                10.verticalSpace,
                Obx(() => '${logic.displayVersion}'.toText
                  ..style = Styles.ts_0C1C33_14sp
                  ..onTap = logic.copyVersion),
                16.verticalSpace,
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 10.w),
                  color: Styles.c_E8EAEF,
                  height: .5,
                ),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: logic.checkUpdate,
                  child: Container(
                    height: 57.h,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        StrRes.checkNewVersion.toText..style = Styles.ts_0C1C33_17sp,
                        const Spacer(),
                        ImageRes.rightArrow.toImage
                          ..width = 24.w
                          ..height = 24.h,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
