import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:openim_common/openim_common.dart';

import '../../live_client.dart';
import '../../trtc_call_session.dart';
import 'widgets/call_state.dart';
import 'widgets/participant.dart';

class SingleRoomView extends SignalView {
  const SingleRoomView({
    super.key,
    required super.callType,
    required super.initState,
    required super.userID,
    required super.callEventSubject,
    required super.autoPickup,
    super.roomID,
    super.onClose,
    super.onBindRoomID,
    super.onBusyLine,
    super.onDial,
    super.onStartCalling,
    super.onTapCancel,
    super.onTapHangup,
    super.onTapPickup,
    super.onTapReject,
    super.onWaitingAccept,
    super.onSyncUserInfo,
    super.onError,
    super.onRoomDisconnected,
  });

  @override
  SignalState<SingleRoomView> createState() => _SingleRoomViewState();
}

class _SingleRoomViewState extends SignalState<SingleRoomView> {
  TRTCCallSession? _session;

  @override
  void dispose() {
    (() async {
      final session = _session;
      session?.removeListener(_onSessionDidUpdate);
      await session?.leave();
      session?.dispose();
    })();
    super.dispose();
  }

  @override
  Future<bool> connect() async {
    final busyLineUsers = certificate.busyLineUserIDList ?? [];
    if (busyLineUsers.isNotEmpty) {
      widget.onBusyLine?.call();
      widget.onClose?.call();
      return false;
    }

    try {
      final session = await TRTCCallSession.create(
        videoCall: widget.callType == CallType.video,
      );
      _session = session
        ..onRemoteUserEntered = () {
          _updateParticipantTracks();
          onParticipantConnected();
        }
        ..onRemoteUserLeft = () {
          _updateParticipantTracks();
          onParticipantDisconnected();
        }
        ..onDisconnected = () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onRoomDisconnected?.call();
            widget.onClose?.call();
          });
        }
        ..onError = (error, stackTrace) {
          Logger.print('TRTC room error: $error $stackTrace');
          widget.onError?.call(error, stackTrace);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onClose?.call();
          });
        };
      session.addListener(_onSessionDidUpdate);
      await session.enter(certificate);
      if (!mounted) {
        await session.leave();
        return false;
      }

      roomDidUpdateSubject.add(session);
      _updateParticipantTracks();
      if (CallState.call == callState || CallState.connecting == callState) {
        widget.onWaitingAccept?.call();
      }
      return true;
    } catch (error, stackTrace) {
      Logger.print('connect TRTC room failed: $error $stackTrace');
      rethrow;
    }
  }

  void _onSessionDidUpdate() {
    _updateParticipantTracks();
    final session = _session;
    if (session != null && !roomDidUpdateSubject.isClosed) {
      roomDidUpdateSubject.add(session);
    }
  }

  void _updateParticipantTracks() {
    final session = _session;
    if (session == null || !mounted) return;

    if (widget.callType == CallType.video) {
      localParticipantTrack = ParticipantTrack(
        session: session,
        userID: certificate.userID ?? '',
        isLocal: true,
        videoAvailable: session.cameraEnabled,
      );
      final remoteUserID = session.remoteUserID;
      remoteParticipantTrack = remoteUserID == null
          ? null
          : ParticipantTrack(
              session: session,
              userID: remoteUserID,
              isLocal: false,
              videoAvailable: session.remoteVideoAvailable,
            );
    } else {
      localParticipantTrack = null;
      remoteParticipantTrack = null;
    }
    setState(() {});
  }

  @override
  bool existParticipants() => _session?.remoteUserID != null;
}
