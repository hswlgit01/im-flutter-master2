import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:openim_common/openim_common.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sprintf/sprintf.dart';
import 'package:uuid/uuid.dart';

import '../openim_live.dart';

/// 信令
mixin OpenIMLive {
  final signalingSubject = PublishSubject<CallEvent>();

  // 通话通知回调（由外部实现）
  Future<void> Function(String title, String body, String payload)? onShowCallNotification;

  void invitationCancelled(SignalingInfo info) {
    signalingSubject.add(CallEvent(CallState.beCanceled, info));
  }

  void inviteeAccepted(SignalingInfo info) {
    signalingSubject.add(CallEvent(CallState.beAccepted, info));
  }

  void inviteeRejected(SignalingInfo info) {
    signalingSubject.add(CallEvent(CallState.beRejected, info));
  }

  void receiveNewInvitation(SignalingInfo info) {
    signalingSubject.add(CallEvent(CallState.beCalled, info));
  }

  void beHangup(SignalingInfo info) {
    signalingSubject.add(CallEvent(CallState.beHangup, info));
  }

  void syncCall(Message msg) {
    String currentSource = Platform.isIOS ? 'ios' : 'android';

    // 解析消息内容获取source
    String? source;
    try {
      final content = jsonDecode(msg.customElem!.data!);
      source = content['data']?['source'];
    } catch (e) {
      Logger.print('Failed to parse syncCall message: $e');
    }

    if (source != currentSource) {
      // 关闭通话弹窗
      OpenIMLiveClient().close();

      // 停止声音播放
      _stopSound();

      // 清空被叫事件
      _beCalledEvent = null;

      // 重置自动接听
      _autoPickup = false;
      IMViews.showToast(StrRes.callHandledByOtherDevice);
    }
  }

  final backgroundSubject = PublishSubject<bool>();

  final insertSignalingMessageSubject = PublishSubject<CallEvent>();

  Function(SignalingMessageEvent)? onSignalingMessage;
  final roomParticipantDisconnectedSubject = PublishSubject<RoomCallingInfo>();
  final roomParticipantConnectedSubject = PublishSubject<RoomCallingInfo>();

  bool _isRunningBackground = false;

  CallEvent? _beCalledEvent;

  bool _autoPickup = false;

  final _ring = 'assets/audio/live_ring.wav';
  final _audioPlayer = AudioPlayer(
    // Handle audio_session events ourselves for the purpose of this demo.
    handleInterruptions: false,
    // androidApplyAudioAttributes: false,
    // handleAudioSessionActivation: false,
  );

  bool get isBusy => OpenIMLiveClient().isBusy;

  onCloseLive() {
    signalingSubject.close();
    backgroundSubject.close();
    roomParticipantDisconnectedSubject.close();
    roomParticipantConnectedSubject.close();
    _stopSound();
  }

  onInitLive() async {
    _signalingListener();
    _insertSignalingMessageListener();
    backgroundSubject.listen((background) {
      Logger.print('[OpenIMLive] 📱 收到后台状态变更: $_isRunningBackground -> $background');
      _isRunningBackground = background;
      Logger.print('[OpenIMLive] ✅ 后台状态已更新: $_isRunningBackground');
      if (!_isRunningBackground) {
        Logger.print('[OpenIMLive] App回到前台');
        if (_beCalledEvent != null) {
          Logger.print('[OpenIMLive] 发现缓存的通话事件，重新触发');
          signalingSubject.add(_beCalledEvent!);
          _beCalledEvent = null; // 触发后清除，避免重复触发
        } else {
          Logger.print('[OpenIMLive] 没有缓存的通话事件');
        }
      }
    });

    roomParticipantDisconnectedSubject.listen((info) {
      if (null == info.participant || info.participant!.length == 1) {
        OpenIMLiveClient().closeByRoomID(info.invitation!.roomID!);
      }
    });
  }

  Stream<CallEvent> get _stream => signalingSubject.stream /*.where((event) => LiveClient.dispatchSignaling(event))*/;

  _signalingListener() => _stream.listen(
        (event) async {
          _beCalledEvent = null;
          if (event.state == CallState.beCalled) {
            Logger.print('[OpenIMLive] ========== 收到通话邀请 ==========');
            Logger.print('[OpenIMLive] _isRunningBackground=$_isRunningBackground');

            // 播放来电铃声（前台和后台都播放）
            _playSound();

            final mediaType = event.data.invitation?.mediaType ?? 'video';
            final sessionType = event.data.invitation?.sessionType ?? ConversationType.single;
            final callType = mediaType == 'audio' ? CallType.audio : CallType.video;
            final callObj = sessionType == ConversationType.single ? CallObj.single : CallObj.group;

            // 如果在后台，显示系统通知
            if (Platform.isAndroid && _isRunningBackground) {
              Logger.print('[OpenIMLive] App在后台，准备显示通话通知');
              _beCalledEvent = event;

              // 显示系统通知
              await _showCallNotification(event.data, mediaType);

              // 检查悬浮窗权限，如果有权限则直接显示通话界面
              if (await Permissions.checkSystemAlertWindow()) {
                Logger.print('[OpenIMLive] 有悬浮窗权限，暂时等待用户从通知栏点击');
                // 注意：这里 return 会阻止通话界面显示，等待用户点击通知后再显示
                // 如果你希望直接弹出界面，可以移除这个 return
                return;
              }
              Logger.print('[OpenIMLive] 无悬浮窗权限，等待用户从通知栏点击');
              // 没有悬浮窗权限，只能等待用户点击通知
              return;
            }

            Logger.print('[OpenIMLive] App在前台，直接显示通话界面');
            _beCalledEvent = null;
            OpenIMLiveClient().start(
              Get.overlayContext!,
              callEventSubject: signalingSubject,
              roomID: event.data.invitation!.roomID!,
              inviteeUserIDList: event.data.invitation!.inviteeUserIDList!,
              inviterUserID: event.data.invitation!.inviterUserID!,
              groupID: event.data.invitation!.groupID,
              callType: callType,
              callObj: callObj,
              initState: CallState.beCalled,
              onSyncUserInfo: onSyncUserInfo,
              onSyncGroupInfo: onSyncGroupInfo,
              onSyncGroupMemberInfo: onSyncGroupMemberInfo,
              autoPickup: _autoPickup,
              onTapPickup: () => onTapPickup(
                event.data..userID = OpenIM.iMManager.userID,
              ),
              onTapReject: () => onTapReject(
                event.data..userID = OpenIM.iMManager.userID,
              ),
              onTapHangup: (duration, isPositive) => onTapHangup(
                event.data..userID = OpenIM.iMManager.userID,
                duration,
                isPositive,
              ),
              onError: onError,
              onRoomDisconnected: () => onRoomDisconnected(event.data),
            );
          } else if (event.state == CallState.beRejected) {
            Logger.print('[OpenIMLive] 📞 收到拒绝信令，停止声音');
            insertSignalingMessageSubject.add(event);
            _stopSound();
            _beCalledEvent = null; // 清除缓存的通话事件
          } else if (event.state == CallState.beHangup) {
            Logger.print('[OpenIMLive] 📞 收到挂断信令，停止声音');
            _stopSound();
            _beCalledEvent = null; // 清除缓存的通话事件
          } else if (event.state == CallState.beCanceled) {
            Logger.print('[OpenIMLive] 📞 收到取消信令，停止声音并关闭界面');
            insertSignalingMessageSubject.add(event);
            _stopSound();
            _beCalledEvent = null; // 清除缓存的通话事件
            // 如果通话界面已经打开，关闭它
            if (event.data.invitation?.roomID != null) {
              OpenIMLiveClient().closeByRoomID(event.data.invitation!.roomID!);
            }
          } else if (event.state == CallState.beAccepted) {
            Logger.print('[OpenIMLive] 📞 收到接受信令，停止声音');
            _stopSound();
            _beCalledEvent = null; // 清除缓存的通话事件
          } else if (event.state == CallState.otherReject || event.state == CallState.otherAccepted) {
            _stopSound();
          } else if (event.state == CallState.timeout) {
            insertSignalingMessageSubject.add(event);

            _stopSound();
            final sessionType = event.data.invitation!.sessionType;

            if (sessionType == 1) {
              onTimeoutCancelled(event.data);
            }
          }
        },
      );

  _insertSignalingMessageListener() {
    insertSignalingMessageSubject.listen((value) {
      _insertMessage(
        state: value.state,
        signalingInfo: value.data,
        duration: value.fields ?? 0,
      );
    });
  }

  call({
    required CallObj callObj,
    required CallType callType,
    CallState callState = CallState.call,
    String? roomID,
    String? inviterUserID,
    required List<String> inviteeUserIDList,
    String? groupID,
    SignalingCertificate? credentials,
  }) async {
    final mediaType = callType == CallType.audio ? 'audio' : 'video';
    final sessionType = callObj == CallObj.single ? 1 : 3;
    inviterUserID ??= OpenIM.iMManager.userID;

    final signal = SignalingInfo(
      userID: inviterUserID,
      invitation: InvitationInfo(
        inviterUserID: inviterUserID,
        inviteeUserIDList: inviteeUserIDList,
        roomID: roomID ?? groupID ?? const Uuid().v4(),
        timeout: 30,
        mediaType: mediaType,
        sessionType: sessionType,
        platformID: IMUtils.getPlatform(),
        groupID: groupID,
      ),
    );

    OpenIMLiveClient().start(
      Get.overlayContext!,
      callEventSubject: signalingSubject,
      inviterUserID: inviterUserID,
      groupID: groupID,
      inviteeUserIDList: inviteeUserIDList,
      callObj: callObj,
      callType: callType,
      initState: callState,
      onDialSingle: () => onDialSingle(signal),
      onJoinGroup: () => Future.value(credentials!),
      onTapCancel: () => onTapCancel(signal),
      onTapHangup: (duration, isPositive) => onTapHangup(
        signal,
        duration,
        isPositive,
      ),
      onSyncUserInfo: onSyncUserInfo,
      onSyncGroupInfo: onSyncGroupInfo,
      onSyncGroupMemberInfo: onSyncGroupMemberInfo,
      onWaitingAccept: () {
        if (callObj == CallObj.single) _playSound();
      },
      onBusyLine: onBusyLine,
      onStartCalling: () {
        _stopSound();
      },
      onError: onError,
      onRoomDisconnected: () => onRoomDisconnected(signal),
      onClose: _stopSound,
    );
  }

  onError(error, stack) {
    Logger.print('onError=====> $error $stack');
    OpenIMLiveClient().close();
    _stopSound();
    if (error is PlatformException) {
      if (int.parse(error.code) == SDKErrorCode.hasBeenBlocked) {
        IMViews.showToast(StrRes.callFail);
        return;
      }
    }
    IMViews.showToast(StrRes.networkError);
  }

  onRoomDisconnected(SignalingInfo signalingInfo) {}

  /// 显示通话系统通知（后台时使用）
  Future<void> _showCallNotification(SignalingInfo signaling, String mediaType) async {
    try {
      // 检查回调是否设置
      if (onShowCallNotification == null) {
        Logger.print('[OpenIMLive] ⚠️ onShowCallNotification 回调未设置，无法显示通知');
        return;
      }

      // 获取调用方信息
      final inviterUserID = signaling.invitation?.inviterUserID;
      if (inviterUserID == null) {
        Logger.print('[OpenIMLive] ❌ 无法显示通话通知：inviterUserID 为空');
        return;
      }

      // 获取用户信息（昵称）
      String callerName = inviterUserID;
      try {
        final userInfo = await OpenIM.iMManager.userManager.getUsersInfo(userIDList: [inviterUserID]);
        if (userInfo.isNotEmpty && userInfo.first.nickname != null) {
          callerName = userInfo.first.nickname!;
        }
      } catch (e) {
        Logger.print('[OpenIMLive] ⚠️ 获取用户信息失败，使用 userID: $e');
      }

      // 准备通知内容
      final isVideo = mediaType == 'video';
      final title = StrRes.offlineCallMessage; // "你收到了一条通话邀请消息"
      final hintTemplate = isVideo ? StrRes.whoInvitedVideoCallHint : StrRes.whoInvitedVoiceCallHint;
      final body = sprintf(hintTemplate, [callerName]);
      final payload = "call://${signaling.invitation?.roomID}/$inviterUserID/$mediaType";

      // 调用外部回调显示通知
      await onShowCallNotification!(title, body, payload);

      Logger.print('[OpenIMLive] ✅ 已调用通话通知回调: $callerName (${isVideo ? "视频" : "语音"})');
    } catch (e, stackTrace) {
      Logger.print('[OpenIMLive] ❌ 显示通话系统通知失败: $e');
      Logger.print('[OpenIMLive] 堆栈: $stackTrace');
    }
  }

  Future<SignalingCertificate> onDialSingle(SignalingInfo signaling) async {
    final data = {'customType': CustomMessageType.callingInvite, 'data': signaling.invitation!.toJson()};
    final message = await OpenIM.iMManager.messageManager
        .createCustomMessage(data: jsonEncode(data), extension: '', description: '');

    // 配置离线推送，支持后台唤醒
    final inviterUserID = signaling.invitation!.inviterUserID ?? OpenIM.iMManager.userID;
    final mediaType = signaling.invitation!.mediaType ?? 'video';
    final isVideo = mediaType == 'video';

    // 获取发起者昵称
    String callerName = inviterUserID;
    try {
      final userInfoList = await OpenIM.iMManager.userManager.getUsersInfo(userIDList: [inviterUserID]);
      if (userInfoList.isNotEmpty && userInfoList.first.nickname != null) {
        callerName = userInfoList.first.nickname!;
      }
    } catch (e) {
      Logger.print('[OpenIMLive] 获取用户信息失败: $e');
    }

    final pushTitle = StrRes.offlineCallMessage; // "你收到了一条通话邀请消息"
    final hintTemplate = isVideo ? StrRes.whoInvitedVideoCallHint : StrRes.whoInvitedVoiceCallHint;
    final pushContent = sprintf(hintTemplate, [callerName]);

    final offlinePush = OfflinePushInfo(
      title: pushTitle,
      desc: pushContent,
      ex: jsonEncode({
        'type': 'call',
        'roomID': signaling.invitation!.roomID,
        'inviterUserID': inviterUserID,
        'mediaType': mediaType,
      }),
      iOSPushSound: 'call.wav',
      iOSBadgeCount: true,
    );

    OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        offlinePushInfo: offlinePush,
        userID: signaling.invitation!.inviteeUserIDList!.first,
        isOnlineOnly: false); // 改为 false，支持离线推送
    final certificate = await Apis.getTokenForRTC(signaling.invitation!.roomID!, OpenIM.iMManager.userID);

    return certificate;
  }

  Future<SignalingCertificate> onTapPickup(SignalingInfo signaling) async {
    _beCalledEvent = null; // ios bug
    _autoPickup = false;
    _stopSound();

    final data = {'customType': CustomMessageType.callingAccept, 'data': signaling.invitation!.toJson()};
    final message = await OpenIM.iMManager.messageManager
        .createCustomMessage(data: jsonEncode(data), extension: '', description: '');
    OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        offlinePushInfo: OfflinePushInfo(),
        userID: signaling.invitation!.inviterUserID,
        isOnlineOnly: true);
    final certificate = await Apis.getTokenForRTC(signaling.invitation!.roomID!, OpenIM.iMManager.userID);

    /// 同步消息
    String source = Platform.isIOS ? 'ios' : 'android';
    final syncData = {
      'customType': CustomMessageType.syncCallStatus,
      'data': {
        'state': 'accept',
        'source': source
      },
    };
    final syncMessage = await OpenIM.iMManager.messageManager.createCustomMessage(data: jsonEncode(syncData), extension: '', description: '');
    OpenIM.iMManager.messageManager.sendMessage(message: syncMessage, offlinePushInfo: OfflinePushInfo(), userID: OpenIM.iMManager.userID, isOnlineOnly: true);

    return certificate;
  }

  onTapReject(SignalingInfo signaling) async {
    _stopSound();
    insertSignalingMessageSubject.add(CallEvent(CallState.reject, signaling));

    final data = {'customType': CustomMessageType.callingReject, 'data': signaling.invitation!.toJson()};
    final message = await OpenIM.iMManager.messageManager
        .createCustomMessage(data: jsonEncode(data), extension: '', description: '');
    final recvUserID = signaling.invitation!.inviterUserID == OpenIM.iMManager.userID
        ? signaling.invitation!.inviteeUserIDList!.first
        : signaling.invitation!.inviterUserID;

    /// 同步消息
    String source = Platform.isIOS ? 'ios' : 'android';
    final syncData = {
      'customType': CustomMessageType.syncCallStatus,
      'data': {
        'state': 'reject',
        'source': source,
      },
    };
    final syncMessage = await OpenIM.iMManager.messageManager.createCustomMessage(data: jsonEncode(syncData), extension: '', description: '');
    OpenIM.iMManager.messageManager.sendMessage(message: syncMessage, offlinePushInfo: OfflinePushInfo(), userID: OpenIM.iMManager.userID, isOnlineOnly: true);

    // 创建离线推送信息，确保后台也能收到拒绝信令
    final offlinePush = OfflinePushInfo(
      title: '通话已拒绝',
      desc: '对方拒绝了您的通话',
      ex: jsonEncode({
        'type': 'call_reject',
        'roomID': signaling.invitation!.roomID,
      }),
    );

    return OpenIM.iMManager.messageManager
        .sendMessage(message: message, offlinePushInfo: offlinePush, userID: recvUserID, isOnlineOnly: false);

  }

  onTapCancel(SignalingInfo signaling) async {
    _stopSound();
    insertSignalingMessageSubject.add(CallEvent(CallState.cancel, signaling));

    final data = {'customType': CustomMessageType.callingCancel, 'data': signaling.invitation!.toJson()};
    final message = await OpenIM.iMManager.messageManager
        .createCustomMessage(data: jsonEncode(data), extension: '', description: '');
    final recvUserID = signaling.invitation!.inviterUserID == OpenIM.iMManager.userID
        ? signaling.invitation!.inviteeUserIDList!.first
        : signaling.invitation!.inviterUserID;

    // 创建离线推送信息，确保后台也能收到取消信令
    final offlinePush = OfflinePushInfo(
      title: '通话已取消',
      desc: '对方取消了通话',
      ex: jsonEncode({
        'type': 'call_cancel',
        'roomID': signaling.invitation!.roomID,
      }),
    );

    OpenIM.iMManager.messageManager
        .sendMessage(message: message, offlinePushInfo: offlinePush, userID: recvUserID, isOnlineOnly: false);
    return true;
  }

  onTimeoutCancelled(SignalingInfo signaling) async {
    final data = {'customType': CustomMessageType.callingCancel, 'data': signaling.invitation!.toJson()};
    final message = await OpenIM.iMManager.messageManager
        .createCustomMessage(data: jsonEncode(data), extension: '', description: '');

    // 创建离线推送信息，确保后台也能收到超时取消信令
    final offlinePush = OfflinePushInfo(
      title: '通话已取消',
      desc: '通话超时已取消',
      ex: jsonEncode({
        'type': 'call_timeout',
        'roomID': signaling.invitation!.roomID,
      }),
    );

    OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        offlinePushInfo: offlinePush,
        userID: signaling.invitation!.inviterUserID,
        isOnlineOnly: false);

    return true;
  }

  onTapHangup(SignalingInfo signaling, int duration, bool isPositive) async {
    if (isPositive) {
      final data = {'customType': CustomMessageType.callingHungup, 'data': signaling.invitation!.toJson()};
      final message = await OpenIM.iMManager.messageManager
          .createCustomMessage(data: jsonEncode(data), extension: '', description: '');
      final recvUserID = signaling.invitation!.inviterUserID == OpenIM.iMManager.userID
          ? signaling.invitation!.inviteeUserIDList!.first
          : signaling.invitation!.inviterUserID;

      // 创建离线推送信息，确保后台也能收到挂断信令
      final offlinePush = OfflinePushInfo(
        title: '通话已结束',
        desc: '对方已挂断',
        ex: jsonEncode({
          'type': 'call_hangup',
          'roomID': signaling.invitation!.roomID,
        }),
      );

      OpenIM.iMManager.messageManager
          .sendMessage(message: message, offlinePushInfo: offlinePush, userID: recvUserID, isOnlineOnly: false);
    }
    _stopSound();

    insertSignalingMessageSubject.add(CallEvent(
      CallState.hangup,
      signaling,
      fields: duration,
    ));
  }

  onBusyLine() {
    _stopSound();
    IMViews.showToast(StrRes.busyVideoCallHint);
  }

  /// 处理通话取消（用于收到通话记录消息时）
  /// 只停止声音和清除缓存，不插入消息记录
  void handleCallCanceled() {
    Logger.print('[OpenIMLive] 📞 处理通话取消记录，停止声音并清除缓存');
    _stopSound();
    _beCalledEvent = null;
    // 尝试关闭通话界面
    try {
      OpenIMLiveClient().close();
    } catch (e) {
      Logger.print('[OpenIMLive] ⚠️ 关闭通话界面失败: $e');
    }
  }

  onJoin() {}

  Future<UserInfo?> onSyncUserInfo(userID) async {
    var list = await OpenIM.iMManager.userManager.getUsersInfo(
      userIDList: [userID],
    );

    return list.firstOrNull?.simpleUserInfo;
  }

  Future<GroupInfo?> onSyncGroupInfo(groupID) async {
    var list = await OpenIM.iMManager.groupManager.getGroupsInfo(
      groupIDList: [groupID],
    );
    return list.firstOrNull;
  }

  Future<List<GroupMembersInfo>> onSyncGroupMemberInfo(groupID, userIDList) async {
    var list = await OpenIM.iMManager.groupManager.getGroupMembersInfo(
      groupID: groupID,
      userIDList: userIDList,
    );
    return list;
  }

  void _playSound() async {
    if (!_audioPlayer.playerState.playing) {
      _audioPlayer.setAsset(_ring, package: 'openim_common');
      _audioPlayer.setLoopMode(LoopMode.one);
      _audioPlayer.setVolume(1.0);
      _audioPlayer.play();
    }
  }

  void _stopSound() async {
    if (_audioPlayer.playerState.playing) {
      _audioPlayer.stop();
    }
  }

  void _insertMessage({
    required CallState state,
    required SignalingInfo signalingInfo,
    int duration = 0,
  }) async {
    (() async {
      var invitation = signalingInfo.invitation;
      var mediaType = invitation!.mediaType;
      var inviterUserID = invitation.inviterUserID;
      var inviteeUserID = invitation.inviteeUserIDList!.first;
      var groupID = invitation.groupID;
      Logger.print(
          'end calling and insert message state:${state.name}, mediaType:$mediaType, inviterUserID:$inviterUserID, inviteeUserID:$inviteeUserID, groupID:$groupID, duration:$duration',
          functionName: '_insertMessage');
      var message = await OpenIM.iMManager.messageManager.createCallMessage(
        state: state.name,
        type: mediaType!,
        duration: duration,
      );

      String? receiverID;
      if (inviterUserID != OpenIM.iMManager.userID) {
        receiverID = inviterUserID;
      } else {
        receiverID = inviteeUserID;
      }
      if (inviterUserID == OpenIM.iMManager.userID) {
        final msg = await OpenIM.iMManager.messageManager.sendMessage(
          message: message,
          offlinePushInfo: OfflinePushInfo(),
          userID: receiverID,
        );
        onSignalingMessage?.call(SignalingMessageEvent(msg, 1, receiverID, null));
      }
    })();
  }
}

class SignalingMessageEvent {
  Message message;
  String? userID;
  String? groupID;
  int sessionType;

  SignalingMessageEvent(
    this.message,
    this.sessionType,
    this.userID,
    this.groupID,
  );

  bool get isSingleChat => sessionType == ConversationType.single;

  bool get isGroupChat => sessionType == ConversationType.group || sessionType == ConversationType.superGroup;
}

extension MessageMangerExt on MessageManager {
  Future<Message> createCallMessage({
    required String type,
    required String state,
    int? duration,
  }) =>
      createCustomMessage(
        data: json.encode({
          "customType": CustomMessageType.call,
          "data": {
            'duration': duration,
            'state': state,
            'type': type,
          },
        }),
        extension: '',
        description: '',
      );
}
