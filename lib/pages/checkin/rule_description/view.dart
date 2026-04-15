import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'logic.dart';

class RuleDescriptionPage extends StatelessWidget {
  final logic = Get.find<RuleDescriptionLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.checkinRuleDescription,
      ),
      backgroundColor: Styles.c_F6F6F6,
      body: Obx(() => _buildBody()),
    );
  }

  Widget _buildBody() {
    if (logic.loading.value) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Styles.c_0089FF,
            ),
            10.verticalSpace,
            Text(
              StrRes.loading,
              style: Styles.ts_8E9AB0_14sp,
            ),
          ],
        ),
      );
    } else if (logic.error.value) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48.sp,
              color: Styles.c_8E9AB0,
            ),
            10.verticalSpace,
            Text(
              logic.errorMessage.value,
              style: Styles.ts_8E9AB0_14sp,
            ),
            20.verticalSpace,
            GestureDetector(
              onTap: logic.retry,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Styles.c_0089FF,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  StrRes.retry,
                  style: Styles.ts_FFFFFF_14sp,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return _buildWebView();
    }
  }

  Widget _buildWebView() {
    return Container(
      margin: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri('file://${logic.htmlFilePath.value}'),
          ),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              useOnLoadResource: true,
              javaScriptEnabled: true,
            ),
          ),
          onLoadError: (controller, url, code, message) {
            logic.error.value = true;
            logic.errorMessage.value = '${StrRes.loadFailedSimple}: $message';
          },
          onLoadHttpError: (controller, url, statusCode, description) {
            logic.error.value = true;
            logic.errorMessage.value = '${StrRes.loadFailedSimple}: HTTP $statusCode $description';
          },
        ),
      ),
    );
  }
}