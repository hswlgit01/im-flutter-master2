import 'package:flutter/material.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import '../../../trtc_call_session.dart';

class ParticipantTrack {
  ParticipantTrack({
    required this.session,
    required this.userID,
    required this.isLocal,
    required this.videoAvailable,
  });

  final TRTCCallSession session;
  final String userID;
  final bool isLocal;
  final bool videoAvailable;
}

class ParticipantWidget extends StatelessWidget {
  const ParticipantWidget({super.key, required this.track});

  final ParticipantTrack track;

  static Widget widgetFor(ParticipantTrack track) =>
      ParticipantWidget(track: track);

  @override
  Widget build(BuildContext context) {
    if (!track.videoAvailable) return Container(color: Colors.black);
    return ColoredBox(
      color: Colors.black,
      child: TRTCCloudVideoView(
        onViewCreated: track.isLocal
            ? track.session.bindLocalView
            : track.session.bindRemoteView,
      ),
    );
  }
}
