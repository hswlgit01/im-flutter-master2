import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'splash_logic.dart';

class SplashPage extends StatelessWidget {
  final logic = Get.find<SplashLogic>();

  SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Styles.c_0089FF_opacity10, Styles.c_FFFFFF_opacity0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 130.h,
            child: ImageRes.splashLogo.toImage
              // dawn 2026-06-30 统一为方形 app 图标，按比例缩放避免拉伸。
              ..width = 78.91.w
              ..height = 78.91.w
              ..fit = BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
