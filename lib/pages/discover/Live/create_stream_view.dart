import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:openim_common/openim_common.dart';
import 'create_stream_logic.dart';
import 'dart:io';

class CreateStreamView extends StatelessWidget {
  final logic = Get.put(CreateStreamLogic());

  CreateStreamView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题和开始直播按钮
            _buildTopBar(),
            
            // 内容区域（滚动部分）
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.h),
                      
                      // 预览画面
                      _buildPreviewWindow(),
                      SizedBox(height: 16.h),
                      
                      // 直播设置
                      _buildLiveSettings(),
                      SizedBox(height: 16.h),
                      
                      // 设备开关面板
                      _buildDeviceControls(),
                      SizedBox(height: 50.h), // 底部空间，防止被导航栏遮挡
                    ],
                  ),
                ),
              ),
            ),
        
          ],
        ),
      ),
    );
  }

  // 顶部标题和开始直播按钮
  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧标题区域
          Row(
            children: [
              // 返回按钮 - 减少右侧边距
              IconButton(
                onPressed: () => Get.back(),
                icon: Icon(Icons.arrow_back_ios, size: 20.r),
                padding: EdgeInsets.zero, // 移除内边距使按钮和文字更近
                constraints: BoxConstraints(),
                color: Color(0xFF333333),
              ),
              // 标题文本
              Text(
                StrRes.startLiveStream,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          
          // 右侧开始直播按钮 - 改为长椭圆形
          Obx(() => ElevatedButton(
            onPressed: logic.isLoading.value ? null : () => logic.startLiveStream(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5B5BD6),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Color(0xFF5B5BD6).withOpacity(0.5),
              elevation: logic.isLoading.value ? 0 : 2,
              shadowColor: Color(0xFF5B5BD6).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              minimumSize: Size(48.w, 36.h),
            ),
            child: logic.isLoading.value 
              ? SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline, size: 20.r),
                    SizedBox(width: 4.w),
                    Text(
                      StrRes.startLiveStream,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
          )),
        ],
      ),
    );
  }

  // 预览画面
  Widget _buildPreviewWindow() {
    return Obx(() {
      final hasError = logic.errorMessage.value.isNotEmpty;
      final hasVideo = logic.localVideo.value != null;
      final cameraEnabled = logic.isCameraEnabled.value;
      
      return Stack(
        children: [
          // 视频预览容器
          Container(
            height: 200.h,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            // 根据摄像头状态显示不同内容
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: hasError 
                ? _buildErrorMessage()
                : hasVideo && cameraEnabled
                  ? VideoTrackRenderer(
                      logic.localVideo.value!,
                    )
                  : _buildCameraPlaceholder(),
            ),
          ),
          
          // 控制按钮
          Positioned(
            right: 10.w,
            bottom: 10.h,
            child: Row(
              children: [
                // 切换摄像头按钮
                if (cameraEnabled)
                  GestureDetector(
                    onTap: () => logic.switchCamera(),
                    child: Container(
                      margin: EdgeInsets.only(right: 8.w),
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 18.r,
                      ),
                    ),
                  ),
                
                // 摄像头状态提示
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cameraEnabled ? Icons.videocam : Icons.videocam_off,
                        size: 14.r,
                        color: cameraEnabled ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        logic.isFrontCamera.value ? StrRes.frontCamera : StrRes.backCamera,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
  
  // 摄像头错误提示
  Widget _buildErrorMessage() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade300,
              size: 40.r,
            ),
            SizedBox(height: 12.h),
            Text(
              logic.errorMessage.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 摄像头未开启时的占位图
  Widget _buildCameraPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 42.r,
            color: Colors.white.withOpacity(0.7),
          ),
          SizedBox(height: 12.h),
          Text(
            StrRes.cameraDisabled,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            StrRes.enableCameraToPreview,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  // 直播设置区域
  Widget _buildLiveSettings() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 18.r,
                color: Color(0xFF5B5BD6),
              ),
              SizedBox(width: 8.w),
              Text(
                StrRes.liveSettings,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          
          // 直播标题输入框
          TextField(
            controller: logic.titleController,
            decoration: InputDecoration(
              hintText: StrRes.plsEnterLiveTitle,
              hintStyle: TextStyle(
                fontSize: 14.sp,
                color: Color(0xFF999999),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Color(0xFFE5E6EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Color(0xFFE5E6EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Color(0xFF5B5BD6)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            style: TextStyle(
              fontSize: 14.sp,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 16.h),
          
          // 直播描述输入框
          TextField(
            controller: logic.descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: StrRes.liveDescription,
              hintStyle: TextStyle(
                fontSize: 14.sp,
                color: Color(0xFF999999),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Color(0xFFE5E6EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Color(0xFFE5E6EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Color(0xFF5B5BD6)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            style: TextStyle(
              fontSize: 14.sp,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 16.h),
          
          // 上传封面
          GestureDetector(
            onTap: () => logic.pickCoverImage(),
            child: Container(
              height: 120.h,
              decoration: BoxDecoration(
                color: Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Color(0xFFE5E6EB)),
              ),
              child: Obx(() {
                if (logic.coverImagePath.value != null) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.file(
                          File(logic.coverImagePath.value!),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 8.w,
                        top: 8.h,
                        child: Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16.r,
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48.w,
                          height: 48.w,
                          decoration: BoxDecoration(
                            color: Color(0xFFECECFD),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 24.r,
                            color: Color(0xFF5B5BD6),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          StrRes.uploadCover,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        
                      ],
                    ),
                  );
                }
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 设备控制和聊天设置
  Widget _buildDeviceControls() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.devices_outlined,
                size: 18.r,
                color: Color(0xFF5B5BD6),
              ),
              SizedBox(width: 8.w),
              Text(
                StrRes.deviceAndInteractionSettings,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          
          // 摄像头开关
          Obx(() => _buildToggleRow(
            icon: Icons.videocam_outlined,
            title: StrRes.camera,
            value: logic.isCameraEnabled.value,
            onChanged: (value) => logic.toggleCamera(value),
          )),
          
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          
          // 麦克风开关
          Obx(() => _buildToggleRow(
            icon: Icons.mic_none_outlined,
            title: StrRes.microphone,
            value: logic.isMicrophoneEnabled.value,
            onChanged: (value) => logic.toggleMicrophone(value),
          )),
          
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          
          // 启用聊天开关
          Obx(() => _buildToggleRow(
            icon: Icons.chat_outlined,
            title: StrRes.enableChat,
            value: logic.isChatEnabled.value,
            onChanged: (value) => logic.toggleChat(value),
          )),
          
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          
          // 允许观众参与开关
          Obx(() => _buildToggleRow(
            icon: Icons.people_outline,
            title: StrRes.allowAudienceParticipation,
            value: logic.isAudienceParticipationEnabled.value,
            onChanged: (value) => logic.toggleAudienceParticipation(value),
            description: StrRes.audienceParticipationDescription,
          )),
        ],
      ),
    );
  }

  // 开关行组件
  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    String? description,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: value ? Color(0xFFECECFD) : Color(0xFFF0F1F5),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(
              icon,
              size: 16.r,
              color: value ? Color(0xFF5B5BD6) : Color(0xFF999999),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                ),
                if (description != null)
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Color(0xFF999999),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: Color(0xFF5B5BD6),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }

}

