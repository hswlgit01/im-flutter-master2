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
    return WillPopScope(
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
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16.h),
              
              // 消息
              Text(
                message,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              
              // 进度条
              if (isIndeterminate)
                LinearProgressIndicator(
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF5B5BD6),
                  ),
                )
              else
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF5B5BD6),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
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
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
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
    if (Get.isDialogOpen == true) {
      Get.back();
      show(
        title: '上传中',
        message: message ?? '正在上传文件...',
        progress: progress,
      );
    }
  }

  /// 关闭对话框
  static void close() {
    if (Get.isDialogOpen == true) {
      Get.back();
    }
  }
} 