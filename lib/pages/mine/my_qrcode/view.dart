import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:qr_flutter/qr_flutter.dart';
import './logic.dart';

class MyQrcodeView extends StatelessWidget {
  final logic = Get.find<MyQrcodeLogic>();

  MyQrcodeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: StrRes.qrcode),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.all(Radius.circular(6.r)),
              boxShadow: [
                BoxShadow(
                  color: Styles.c_8E9AB0_opacity13,
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AvatarView(
                      url: logic.imLogic.userInfo.value.faceURL,
                      text: logic.imLogic.userInfo.value.nickname,
                      width: 50.w,
                      height: 50.h,
                    ),
                    10.horizontalSpace,
                    Text(
                      logic.imLogic.userInfo.value.nickname ?? "",
                      style: Styles.ts_0C1C33_20sp_medium,
                    )
                  ],
                ),
                60.verticalSpace,
                Text(StrRes.qrcodeHint, style: Styles.ts_8E9AB0_16sp),
                30.verticalSpace,
                Container(
                  width: 190.w,
                  height: 190.h,
                  color: Styles.c_F8F9FA,
                  child: QrImageView(
                    data:
                        "${Config.friendScheme}${logic.imLogic.userInfo.value.userID}",
                    version: QrVersions.auto,
                    size: 190.w,
                  ),
                ),
                60.verticalSpace,
              ],
            ),
          )
        ],
      ),
    );
  }
}
