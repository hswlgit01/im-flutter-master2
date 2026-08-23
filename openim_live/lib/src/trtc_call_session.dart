import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openim_common/openim_common.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/tx_device_manager.dart';

/// Owns the Tencent RTC engine state for one 1:1 call. OpenIM continues to
/// carry invitation/accept/hangup signaling; this class only handles media.
class TRTCCallSession extends ChangeNotifier {
  TRTCCallSession._(this._cloud, this.videoCall);

  final TRTCCloud _cloud;
  final bool videoCall;

  TRTCCloudListener? _listener;
  Completer<void>? _enterCompleter;
  Completer<void>? _exitCompleter;
  bool _closing = false;
  int? _localViewID;
  int? _remoteViewID;

  bool connected = false;
  bool microphoneEnabled = true;
  bool cameraEnabled = true;
  bool speakerEnabled = true;
  bool frontCamera = true;
  String? remoteUserID;
  bool remoteVideoAvailable = false;

  VoidCallback? onRemoteUserEntered;
  VoidCallback? onRemoteUserLeft;
  VoidCallback? onDisconnected;
  void Function(Object error, StackTrace stackTrace)? onError;

  static Future<TRTCCallSession> create({required bool videoCall}) async {
    final cloud = await TRTCCloud.sharedInstance();
    return TRTCCallSession._(cloud, videoCall);
  }

  static Future<void> ensurePermissions({required bool videoCall}) async {
    final permissions = <Permission>[
      Permission.microphone,
      if (videoCall) Permission.camera,
    ];
    final statuses = await permissions.request();
    final denied = statuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key == Permission.camera ? '摄像头' : '麦克风')
        .toList();
    if (denied.isNotEmpty) {
      throw StateError('请允许${denied.join('、')}权限后重试');
    }
  }

  Future<void> enter(SignalingCertificate certificate) async {
    if (certificate.provider != 'trtc') {
      throw StateError('服务端 RTC provider 不是 TRTC');
    }
    final sdkAppID = certificate.sdkAppID;
    final userID = certificate.userID;
    final userSig = certificate.userSig;
    final roomID = certificate.roomID;
    if (sdkAppID == null ||
        sdkAppID <= 0 ||
        userID == null ||
        userID.isEmpty ||
        userSig == null ||
        userSig.isEmpty ||
        roomID == null ||
        roomID.isEmpty) {
      throw StateError('TRTC 凭证不完整');
    }

    _enterCompleter = Completer<void>();
    _listener = TRTCCloudListener(
      onError: (code, message) {
        final error = StateError('TRTC error $code: $message');
        if (_enterCompleter?.isCompleted == false) {
          _enterCompleter!.completeError(error, StackTrace.current);
        }
        onError?.call(error, StackTrace.current);
      },
      onEnterRoom: (result) {
        if (_enterCompleter?.isCompleted == true) return;
        if (result < 0) {
          _enterCompleter!.completeError(
            StateError('TRTC enterRoom failed: $result'),
            StackTrace.current,
          );
          return;
        }
        connected = true;
        _enterCompleter!.complete();
        notifyListeners();
      },
      onExitRoom: (reason) {
        connected = false;
        if (_exitCompleter?.isCompleted == false) {
          _exitCompleter!.complete();
        }
        notifyListeners();
        if (!_closing) onDisconnected?.call();
      },
      onRemoteUserEnterRoom: (userID) {
        remoteUserID = userID;
        onRemoteUserEntered?.call();
        notifyListeners();
      },
      onRemoteUserLeaveRoom: (userID, _) {
        if (remoteUserID != userID) return;
        remoteUserID = null;
        remoteVideoAvailable = false;
        onRemoteUserLeft?.call();
        notifyListeners();
      },
      onUserVideoAvailable: (userID, available) {
        remoteUserID ??= userID;
        if (remoteUserID != userID) return;
        remoteVideoAvailable = available;
        if (available && _remoteViewID != null) {
          _cloud.startRemoteView(
              userID, TRTCVideoStreamType.big, _remoteViewID);
        } else if (!available) {
          _cloud.stopRemoteView(userID, TRTCVideoStreamType.big);
        }
        notifyListeners();
      },
    );
    _cloud.registerListener(_listener!);
    _cloud.enterRoom(
      TRTCParams(
        sdkAppId: sdkAppID,
        userId: userID,
        userSig: userSig,
        roomId: 0,
        strRoomId: roomID,
      ),
      videoCall ? TRTCAppScene.videoCall : TRTCAppScene.audioCall,
    );

    await _enterCompleter!.future.timeout(const Duration(seconds: 15));
    _cloud.startLocalAudio(TRTCAudioQuality.defaultMode);
    _cloud.getDeviceManager().setAudioRoute(TXAudioRoute.speakerPhone);
    if (!videoCall) cameraEnabled = false;
    notifyListeners();
  }

  void bindLocalView(int viewID) {
    _localViewID = viewID;
    if (videoCall && cameraEnabled) {
      _cloud.startLocalPreview(frontCamera, viewID);
    }
  }

  void bindRemoteView(int viewID) {
    _remoteViewID = viewID;
    final userID = remoteUserID;
    if (userID != null && remoteVideoAvailable) {
      _cloud.startRemoteView(userID, TRTCVideoStreamType.big, viewID);
    }
  }

  void setMicrophoneEnabled(bool enabled) {
    microphoneEnabled = enabled;
    _cloud.muteLocalAudio(!enabled);
    notifyListeners();
  }

  void setCameraEnabled(bool enabled) {
    if (!videoCall) return;
    cameraEnabled = enabled;
    if (enabled) {
      final viewID = _localViewID;
      if (viewID != null) _cloud.startLocalPreview(frontCamera, viewID);
      _cloud.muteLocalVideo(TRTCVideoStreamType.big, false);
    } else {
      _cloud.muteLocalVideo(TRTCVideoStreamType.big, true);
      _cloud.stopLocalPreview();
    }
    notifyListeners();
  }

  void setSpeakerEnabled(bool enabled) {
    speakerEnabled = enabled;
    _cloud.getDeviceManager().setAudioRoute(
          enabled ? TXAudioRoute.speakerPhone : TXAudioRoute.earpiece,
        );
    notifyListeners();
  }

  void switchCamera() {
    frontCamera = !frontCamera;
    _cloud.getDeviceManager().switchCamera(frontCamera);
    notifyListeners();
  }

  Future<void> leave() async {
    if (_closing) return;
    _closing = true;
    _exitCompleter = Completer<void>();
    if (remoteUserID != null) {
      _cloud.stopRemoteView(remoteUserID!, TRTCVideoStreamType.big);
    }
    _cloud.stopLocalPreview();
    _cloud.stopLocalAudio();
    _cloud.exitRoom();
    try {
      await _exitCompleter!.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // The native SDK may omit the callback during process shutdown.
    }
    if (_listener != null) _cloud.unRegisterListener(_listener!);
    connected = false;
  }

  @override
  void dispose() {
    leave();
    super.dispose();
  }
}
