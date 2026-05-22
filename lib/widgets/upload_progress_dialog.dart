import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UploadProgressDialog extends StatelessWidget {
  final String title;
  final String message;
  final double progress;
  final bool isIndeterminate;
  final VoidCallback? onCancel;

  // dawn 2026-05-22 修复手机端上传弹窗闪烁：用响应式状态更新进度，避免每次进度变化都关闭并重新打开弹窗。
  static final RxString _title = ''.obs;
  static final RxString _message = ''.obs;
  static final RxDouble _progress = 0.0.obs;
  static final RxBool _isIndeterminate = false.obs;
  static VoidCallback? _onCancel;
  static bool _isShowing = false;

  const UploadProgressDialog({
    Key? key,
    required this.title,
    required this.message,
    this.progress = 0.0,
    this.isIndeterminate = false,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => WillPopScope(
        onWillPop: () async => false, // 防止返回键关闭对话框
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Container(
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Text(
                  _title.value.isNotEmpty ? _title.value : title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 16.h),

                // 消息
                Text(
                  _message.value.isNotEmpty ? _message.value : message,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),

                // 进度条
                if (_isIndeterminate.value)
                  LinearProgressIndicator(
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF5B5BD6),
                    ),
                  )
                else
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _progress.value,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF5B5BD6),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '${(_progress.value * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: 24.h),

                // 取消按钮
                if (_onCancel != null)
                  TextButton(
                    onPressed: _onCancel,
                    child: Text(
                      StrRes.cancel,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示上传进度对话框
  static void show({
    required String title,
    required String message,
    double progress = 0.0,
    bool isIndeterminate = false,
    VoidCallback? onCancel,
  }) {
    _title.value = title;
    _message.value = message;
    _progress.value = progress.clamp(0.0, 1.0).toDouble();
    _isIndeterminate.value = isIndeterminate;
    _onCancel = onCancel;
    if (_isShowing && Get.isDialogOpen == true) {
      return;
    }
    _isShowing = true;
    Get.dialog(
      UploadProgressDialog(
        title: title,
        message: message,
        progress: progress,
        isIndeterminate: isIndeterminate,
        onCancel: onCancel,
      ),
      barrierDismissible: false,
    );
  }

  /// 更新进度
  static void updateProgress({
    double progress = 0.0,
    String? message,
  }) {
    _progress.value = progress.clamp(0.0, 1.0).toDouble();
    if (message != null) {
      _message.value = message;
    }
  }

  /// 关闭对话框
  static void close() {
    if (_isShowing && Get.isDialogOpen == true) {
      Get.back();
    }
    _isShowing = false;
    _onCancel = null;
  }
}
