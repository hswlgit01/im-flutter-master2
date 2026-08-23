import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_live/src/widgets/live_button.dart';
import 'package:synchronized/synchronized.dart';

import '../../../live_client.dart';
import '../../../trtc_call_session.dart';
import '../../../widgets/loading_view.dart';

class ControlsView extends StatefulWidget {
  const ControlsView({
    Key? key,
    this.initState = CallState.call,
    this.callType = CallType.video,
    required this.callStateStream,
    required this.roomDidUpdateStream,
    this.userInfo,
    this.onMinimize,
    this.onCallingDuration,
    this.onEnabledMicrophone,
    this.onEnabledSpeaker,
    this.onCancel,
    this.onHangUp,
    this.onPickUp,
    this.onReject,
    this.onChangedCallState,
  }) : super(key: key);
  final Stream<TRTCCallSession> roomDidUpdateStream;
  final Stream<CallState> callStateStream;
  final CallState initState;
  final CallType callType;
  final UserInfo? userInfo;
  final Function()? onMinimize;
  final Function(int duration)? onCallingDuration;
  final Function(bool enabled)? onEnabledMicrophone;
  final Function(bool enabled)? onEnabledSpeaker;
  final Function()? onPickUp;
  final Function()? onCancel;
  final Function()? onReject;
  final Function(bool isPositive)? onHangUp;
  final Function(CallState state)? onChangedCallState;

  @override
  State<ControlsView> createState() => _ControlsViewState();
}

class _ControlsViewState extends State<ControlsView> {
  late CallState _callState;
  Timer? _callingTimer;
  int _callingDuration = 0;
  String _callingDurationStr = "00:00";

  StreamSubscription<CallState>? _callStateChangedSub;
  StreamSubscription<TRTCCallSession>? _roomDidUpdateSub;

  TRTCCallSession? _session;

  /// 默认启用麦克风
  bool _enabledMicrophone = true;

  /// 默认开启扬声器
  bool _enabledSpeaker = true;

  final _lockAudio = Lock();
  final _lockSpeaker = Lock();

  @override
  void dispose() {
    _callStateChangedSub?.cancel();
    _roomDidUpdateSub?.cancel();
    _callingTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    _onChangedCallState(widget.initState);
    _callStateChangedSub = widget.callStateStream.listen(_onChangedCallState);
    _roomDidUpdateSub = widget.roomDidUpdateStream.listen(_roomDidUpdate);
    super.initState();
  }

  _roomDidUpdate(TRTCCallSession session) {
    _session = session;
    if (mounted) setState(() {});
  }

  _onChangedCallState(CallState state) {
    if (!mounted) return;
    widget.onChangedCallState?.call(state);
    setState(() {
      _callState = state;
      if (_callState == CallState.calling) {
        _startCallingTimer();
      }
    });
  }

  void _startCallingTimer() {
    _callingTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _callingDurationStr = IMUtils.seconds2HMS(++_callingDuration);
        widget.onCallingDuration?.call(_callingDuration);
      });
    });
  }

  void _toggleAudio() async {
    await _lockAudio.synchronized(() async {
      _enabledMicrophone = !_enabledMicrophone;
      widget.onEnabledMicrophone?.call(_enabledMicrophone);
      if (_enabledMicrophone) {
        await _enableAudio();
      } else {
        await _disableAudio();
      }
    });

    // if (null != _participant) {
    //   if (_participant!.isMicrophoneEnabled()) {
    //     _disableAudio();
    //   } else {
    //     _enableAudio();
    //   }
    // }
  }

  void _toggleSpeaker() async {
    await _lockSpeaker.synchronized(() async {
      _enabledSpeaker = !_enabledSpeaker;
      widget.onEnabledSpeaker?.call(_enabledSpeaker);
      if (_enabledSpeaker) {
        await _enableSpeaker();
      } else {
        await _disableSpeaker();
      }
      setState(() {});
    });
  }

  Future<void> _disableAudio() async {
    _session?.setMicrophoneEnabled(false);
  }

  Future<void> _enableAudio() async {
    _session?.setMicrophoneEnabled(true);
  }

  Future<void> _disableVideo() async {
    _session?.setCameraEnabled(false);
    if (mounted) setState(() {});
  }

  Future<void> _enableVideo() async {
    _session?.setCameraEnabled(true);
    if (mounted) setState(() {});
  }

  Future<void> _disableSpeaker() async {
    _session?.setSpeakerEnabled(false);
  }

  Future<void> _enableSpeaker() async {
    _session?.setSpeakerEnabled(true);
  }

  void _toggleCamera() async {
    _session?.switchCamera();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 16.w,
              top: 7.h,
              child: ImageRes.liveClose.toImage
                ..width = 30.w
                ..height = 30.h
                ..onTap = widget.onMinimize,
            ),
            if (null != _session)
              Positioned(
                right: 16.w,
                top: 7.h,
                child: Visibility(
                  visible: isVideo,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      (_session!.cameraEnabled
                              ? ImageRes.liveCameraOff
                              : ImageRes.liveCameraOn)
                          .toImage
                        ..width = 30.w
                        ..height = 30.h
                        ..onTap = (_session!.cameraEnabled
                            ? _disableVideo
                            : _enableVideo),
                      16.horizontalSpace,
                      ImageRes.liveSwitchCamera.toImage
                        ..width = 30.w
                        ..height = 30.h
                        ..onTap = _toggleCamera,
                    ],
                  ),
                ),
              ),
            if (null != widget.userInfo)
              Positioned(
                top: 166.h,
                width: 1.sw,
                child: _userInfoView,
              ),
            Positioned(
              bottom: 32.h,
              width: 1.sw,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buttonGroup,
              ),
            ),
            Positioned(
              bottom: 156.h,
              width: 1.sw,
              child: Center(child: _videoCallingDurationView),
            ),
            if (_callState == CallState.connecting) const LiveLoadingView(),
          ],
        ),
      );

  List<Widget> get _buttonGroup {
    if (_callState == CallState.call ||
        _callState == CallState.connecting &&
            widget.initState == CallState.call) {
      return [
        LiveButton.microphone(on: _enabledMicrophone, onTap: _toggleAudio),
        LiveButton.cancel(onTap: widget.onCancel),
        LiveButton.speaker(on: _enabledSpeaker, onTap: _toggleSpeaker),
      ];
    } else if (_callState == CallState.beCalled ||
        _callState == CallState.connecting &&
            widget.initState == CallState.beCalled) {
      return [
        LiveButton.reject(onTap: widget.onReject),
        LiveButton.pickUp(onTap: widget.onPickUp),
      ];
    } else if (_callState == CallState.calling) {
      return [
        LiveButton.microphone(on: _enabledMicrophone, onTap: _toggleAudio),
        LiveButton.hungUp(onTap: () => widget.onHangUp?.call(true)),
        LiveButton.speaker(on: _enabledSpeaker, onTap: _toggleSpeaker),
      ];
    }
    return [];
  }

  bool get isVideo => widget.callType == CallType.video;

  bool get isCalling => _callState == CallState.calling;

  Widget get _videoCallingDurationView => Visibility(
        visible: isVideo && isCalling,
        child: _callingDurationStr.toText
          ..style = Styles.ts_FFFFFF_opacity70_17sp,
      );

  Widget get _userInfoView {
    String text;
    if (_callState == CallState.call) {
      text =
          isVideo ? StrRes.waitingVideoCallHint : StrRes.waitingVoiceCallHint;
    } else if (_callState == CallState.beCalled) {
      text =
          isVideo ? StrRes.invitedVideoCallHint : StrRes.invitedVoiceCallHint;
    } else if (_callState == CallState.connecting) {
      text = StrRes.connecting;
    } else {
      text = isVideo ? '' : _callingDurationStr;
    }

    String? nickname = IMUtils.emptyStrToNull(widget.userInfo!.remark) ??
        widget.userInfo!.nickname;
    String? faceURL = widget.userInfo!.faceURL;

    return Visibility(
      visible: !(isVideo && isCalling),
      child: Column(
        children: [
          AvatarView(width: 70.w, height: 70.h, text: nickname, url: faceURL),
          10.verticalSpace,
          (nickname ?? '').toText..style = Styles.ts_FFFFFF_20sp_medium,
          10.verticalSpace,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: text.toText
              ..style = Styles.ts_FFFFFF_opacity70_17sp
              ..maxLines = 1
              ..overflow = TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
