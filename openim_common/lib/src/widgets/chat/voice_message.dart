import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'package:just_audio/just_audio.dart';

class VoiceMessage extends StatefulWidget {
  final Message message;
  final bool isISend;
  final double fontSize;
  final double iconSize;
  const VoiceMessage(
      {super.key,
      required this.message,
      this.isISend = false,
      this.fontSize = 17,
      this.iconSize = 18});
  @override
  State<VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<VoiceMessage> {
  late final AudioPlayerManager _audioManager;
  late final Stream<PlayerState> _playerStateStream;

  @override
  void initState() {
    super.initState();
    _audioManager = AudioPlayerManager();
    _playerStateStream = _audioManager.playerStateStream;
    AudioCacheManager().getLocalPath(widget.message);
  }

  String get playingId => widget.message.clientMsgID ?? "";

  bool get isPlaying => _audioManager.currentId == playingId;

  String get imageIcon =>
      widget.isISend ? ImageRes.voiceBlack : ImageRes.voiceBlue;
  String get animaIconPath => widget.isISend
      ? "assets/anim/voice_black.json"
      : "assets/anim/voice_blue.json";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
        stream: _playerStateStream,
        builder: (context, snapshot) {
          final isActive = isPlaying &&
              snapshot.data?.playing == true &&
              snapshot.data?.processingState != ProcessingState.completed;
          return Row(
            children: [
              Text('${widget.message.soundElem?.duration ?? ''}″',
                  style: TextStyle(
                    color: widget.isISend ? Styles.c_000000 : Styles.c_0089FF,
                    fontSize: widget.fontSize.sp,
                  )),
              Visibility(
                  visible: !isActive,
                  child: imageIcon.toImage..width = widget.iconSize.w),
              Visibility(
                  visible: isActive,
                  child: LottieView(
                    name: animaIconPath,
                    width: widget.iconSize.w,
                  ))
            ],
          );
        });
  }
}
