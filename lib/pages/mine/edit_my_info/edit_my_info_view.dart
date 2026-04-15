import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'edit_my_info_logic.dart';

class EditMyInfoPage extends StatelessWidget {
  final logic = Get.find<EditMyInfoLogic>();
  EditMyInfoPage({super.key});

  @override
  Widget build(BuildContext context) {    return Scaffold(
      appBar: TitleBar.back(
        title: logic.title,
        right: Obx(() => logic.hasContentChanged.value 
            ? (StrRes.save.toText
                ..style = Styles.ts_0C1C33_17sp
                ..onTap = logic.save)
            : const SizedBox.shrink()),
      ),backgroundColor: Styles.c_FFFFFF,
      body: Obx(() => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              32.verticalSpace,
              
              // 标题区域
              Text(
                StrRes.editInfo,
                style: Styles.ts_0C1C33_17sp.copyWith(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              8.verticalSpace,
              Text(
                StrRes.pleaseEnterNewInfo,
                style: Styles.ts_8E9AB0_17sp.copyWith(fontSize: 14.sp),
              ),
              
              32.verticalSpace,
              
              // 主输入框
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFE8EAEF),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: logic.inputCtrl,
                  focusNode: logic.focusNode,
                  style: Styles.ts_0C1C33_17sp.copyWith(fontSize: 16.sp),
                  keyboardType: logic.keyboardType,
                  inputFormatters: [LengthLimitingTextInputFormatter(logic.maxLength)],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16.h,
                      horizontal: 16.w,
                    ),
                    hintText: StrRes.pleaseEnterContent,
                    hintStyle: Styles.ts_8E9AB0_17sp.copyWith(fontSize: 16.sp),
                  ),
                ),
              ),          
          // 邮箱验证码区域
          if (logic.isEmailEdit.value && logic.showVerificationSection.value) ...[
            32.verticalSpace,
            
            // 验证码标题
            Text(
              StrRes.emailVerification,
              style: Styles.ts_0C1C33_17sp.copyWith(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            12.verticalSpace,
            
            // 验证码输入区域
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: const Color(0xFFE8EAEF),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: logic.verificationCodeCtrl,
                      style: Styles.ts_0C1C33_17sp.copyWith(fontSize: 16.sp),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: StrRes.plsEnterVerificationCode,
                        hintStyle: Styles.ts_8E9AB0_17sp.copyWith(fontSize: 16.sp),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 16.h,
                          horizontal: 16.w,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 40.h,
                    width: 1,
                    color: const Color(0xFFE8EAEF),
                    margin: EdgeInsets.symmetric(horizontal: 8.w),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 12.w),
                    child: VerifyCodeSendButton(
                      onTapCallback: logic.sendEmailVerificationCode,
                      auto: false,
                    ),
                  ),
                ],
              ),
            ),
            
            // 提示文本
            16.verticalSpace,
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: const Color(0xFFE1E7EF),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16.sp,
                    color: const Color(0xFF6B7280),
                  ),
                  8.horizontalSpace,
                  Expanded(
                    child: Text(
                      StrRes.emailVerificationHint,
                      style: Styles.ts_8E9AB0_12sp.copyWith(
                        fontSize: 13.sp,
                        height: 1.4,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // 底部间距
          60.verticalSpace,
        ],
      ),
    ),
  )),
    );
  }
}
