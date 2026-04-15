import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../../../utils/log_util.dart';
import '../../../utils/file_upload_helper.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'meeting_view.dart';
import '../../../core/api_service.dart' as core;

class CreateStreamLogic extends GetxController {
  static const String TAG = "CreateStreamLogic";
  final apiService = core.ApiService();

  // 控制器
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // IM控制器，用于获取用户信息
  final imLogic = Get.find<IMController>();

  // 状态变量
  final isLoading = false.obs;
  final errorMessage = "".obs;
  final coverImagePath = Rxn<String>();
  final coverImageUrl = Rxn<String>();

  // 设备开关状态
  final isCameraEnabled = true.obs;
  final isMicrophoneEnabled = true.obs;
  final isChatEnabled = true.obs;
  final isAudienceParticipationEnabled = true.obs;
  final isPreviewEffectEnabled = false.obs;

  // LiveKit相关变量
  final localVideo = Rxn<LocalVideoTrack>();
  final localAudio = Rxn<LocalAudioTrack>();

  // 摄像头方向状态
  final isFrontCamera = true.obs;

  // 图片选择器
  final _picker = ImagePicker();

  @override
  void onInit() async {
    super.onInit();
    // 初始化预览
    await initPreview();
  }

  @override
  void onClose() {
    // 释放资源
    _disposeLocalTracks();
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  // 初始化预览
  Future<void> initPreview() async {
    try {
      errorMessage.value = "";

      // 请求必要的权限
      final hasCameraPermission = await Permission.camera.request().isGranted;
      final hasMicPermission = await Permission.microphone.request().isGranted;

      if (!hasCameraPermission || !hasMicPermission) {
        errorMessage.value = "permitCameraAndMic".tr;
        return;
      }

      // 初始化摄像头预览
      if (isCameraEnabled.value) {
        localVideo.value = await LocalVideoTrack.createCameraTrack();
      }

      // 初始化麦克风
      if (isMicrophoneEnabled.value) {
        localAudio.value = await LocalAudioTrack.create();
      }
    } catch (e) {
      errorMessage.value = "initLiveDevicesFailed".tr;
    }
  }

  // 释放本地轨道
  void _disposeLocalTracks() {
    if (localVideo.value != null) {
      localVideo.value!.stop();
      localVideo.value = null;
    }

    if (localAudio.value != null) {
      localAudio.value!.stop();
      localAudio.value = null;
    }
  }

  // 切换摄像头开关
  Future<void> toggleCamera(bool value) async {
    isCameraEnabled.value = value;

    if (value) {
      if (localVideo.value == null) {
        localVideo.value = await LocalVideoTrack.createCameraTrack();
      }
    } else if (localVideo.value != null) {
      await localVideo.value!.stop();
      localVideo.value = null;
    }
  }

  // 切换麦克风开关
  Future<void> toggleMicrophone(bool value) async {
    isMicrophoneEnabled.value = value;

    if (value) {
      if (localAudio.value == null) {
        localAudio.value = await LocalAudioTrack.create();
      }
    } else if (localAudio.value != null) {
      await localAudio.value!.stop();
      localAudio.value = null;
    }
  }

  // 切换聊天开关
  void toggleChat(bool value) {
    isChatEnabled.value = value;
  }

  // 切换观众参与开关
  void toggleAudienceParticipation(bool value) {
    isAudienceParticipationEnabled.value = value;
  
  }

  // 翻转摄像头
  Future<void> switchCamera() async {
    try {
      if (localVideo.value != null) {
        // 停止当前摄像头
        await localVideo.value!.stop();
        localVideo.value = null;

        // 更新摄像头方向状态
        isFrontCamera.value = !isFrontCamera.value;
        
        // 重新创建摄像头，明确指定要切换的摄像头
        localVideo.value =
            await LocalVideoTrack.createCameraTrack(CameraCaptureOptions(
          cameraPosition:
              isFrontCamera.value ? CameraPosition.front : CameraPosition.back,
        ));

      }
    } catch (e) {
      LogUtil.e(TAG, 'switchCameraFailed'.tr + ': $e');
    }
  }

  // 选择封面图片
  Future<void> pickCoverImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        coverImagePath.value = image.path;
        // 上传图片到服务器
        await uploadCoverImage(image.path);
      }
    } catch (e) {
      LogUtil.e(TAG, '选择封面图片失败: $e');
      Get.snackbar(StrRes.error, e.toString());
    }
  }

  // 上传封面图片
  Future<void> uploadCoverImage(String imagePath) async {
    try {
      isLoading.value = true;
      
      // 使用文件上传助手
      final url = await FileUploadHelper.uploadImage(
        imagePath: imagePath,
        customFileName: 'live_cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
        showProgress: true,
        progressTitle: '上传中',
        progressMessage: '正在上传封面图片...',
      );
      
      if (url != null) {
        coverImageUrl.value = url;
        Get.snackbar(StrRes.success, StrRes.uploadCoverSuccess);
      } else {
        throw Exception(StrRes.uploadCoverFailed);
      }
    } catch (e) {
      LogUtil.e(TAG, '上传封面图片失败: $e');
      Get.snackbar(StrRes.error, e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // 开始直播
  Future<void> startLiveStream() async {
    if (titleController.text.isEmpty) {
      Get.snackbar(StrRes.reminder, StrRes.plsEnterLiveTitle);
      return;
    }

    try {
      isLoading.value = true;

      // 调用API批准举手请求
      final result = await apiService.createStream(
        metadata: {
          'nickname': titleController.text,
          'detail': descriptionController.text.isEmpty
              ? StrRes.liveWelcomeDefault
              : descriptionController.text,
          'enable_chat': isChatEnabled.value,
          'allow_participation': isAudienceParticipationEnabled.value,
          'cover': coverImageUrl.value ?? "",
        },
      );

      if (null != result) {
        final connectionDetails = result['connection_details'];
        final token = connectionDetails['token'];
        final wsUrl = connectionDetails['ws_url'];

        // 释放当前直播资源
        _disposeLocalTracks();

        // 跳转到会议页面
        Get.off(
          () => MeetingPage(), 
          arguments: {
            'liveStreamName': titleController.text,
            'description': descriptionController.text,
            'wsUrl': wsUrl,
            'token': token,
            'isHost': true,
            'isCameraEnabled': isCameraEnabled.value,
            'isMicrophoneEnabled': isMicrophoneEnabled.value,
            'isChatEnabled': isChatEnabled.value,
            'isAudienceParticipationEnabled':
                isAudienceParticipationEnabled.value,
            'isFrontCamera': isFrontCamera.value,
            'coverUrl': coverImageUrl.value,
          },
          transition: Transition.rightToLeft,
          popGesture: false, // 禁用侧滑返回手势
        );

        Get.snackbar(StrRes.success, StrRes.liveStarted,
            backgroundColor: Colors.green.shade100,
            colorText: Colors.black87,
            duration: Duration(seconds: 2));
      } else {
        throw Exception(StrRes.createLiveFailed);
      }
    } catch (e) {
      isLoading.value = false;
      // Get.snackbar(StrRes.error, StrRes.startLiveFailed,
      //     backgroundColor: Colors.red.shade100,
      //     colorText: Colors.black87,
      //     duration: Duration(seconds: 2));
    } finally {
      isLoading.value = false;
    }
  }
}
