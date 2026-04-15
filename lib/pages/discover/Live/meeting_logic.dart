import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 添加Clipboard支持
import 'package:get/get.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';
import '../../../utils/log_util.dart';
import '../../../routes/app_navigator.dart'; // 修正导入路径
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:openim/pages/contacts/select_contacts/select_contacts_logic.dart';
import '../../../core/api_service.dart' as core;
import 'package:uuid/uuid.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

// 定义枚举类型，用于选择动作

// 会议消息
class ChatMessage {
  final String sender;
  final String content;
  final String role;
  final DateTime timestamp;
  final String? faceURL; // 添加头像URL字段

  ChatMessage({
    required this.sender,
    required this.content,
    required this.role,
    required this.timestamp,
    this.faceURL, // 头像URL可以为空
  });
}

// 举手请求
class RaisedHandRequest {
  final String user_id;
  final String user_name;
  final DateTime timestamp;

  RaisedHandRequest({
    required this.user_id,
    required this.user_name,
    required this.timestamp,
  });

  void dispose() {
    // 保留空方法以兼容现有代码
  }
}

// 用户角色枚举
enum UserRole {
  owner, // 主持人
  admin, // 管理员
  publisher, // 参与者
  user, // 普通观众
}

// 用户元数据类
class ParticipantMetadata {
  final UserRole role;
  final bool hand_raised;
  final bool invited_to_stage;
  final String? user_id;
  final String? user_name;
  final String? faceURL;

  ParticipantMetadata({
    this.role = UserRole.user,
    this.hand_raised = false,
    this.invited_to_stage = false,
    this.user_id,
    this.user_name,
    this.faceURL,
  });

  // 将字符串转换为UserRole枚举
  static UserRole _roleFromString(dynamic roleValue) {
    // 如果是复杂的角色对象
    if (roleValue is Map) {
      String roleName = '';
      // 处理复杂角色对象格式
      if (roleValue.containsKey('name')) {
        roleName = roleValue['name'].toString().toLowerCase();
      }
      switch (roleName) {
        case 'owner':
          return UserRole.owner;
        case 'admin':
          return UserRole.admin;
        case 'publisher':
          return UserRole.publisher;
        case 'user':
        default:
          return UserRole.user;
      }
    }
    // 如果是简单的字符串
    else if (roleValue is String) {
      switch (roleValue.toLowerCase()) {
        case 'owner':
          return UserRole.owner;
        case 'admin':
          return UserRole.admin;
        case 'publisher':
          return UserRole.publisher;
        case 'user':
        default:
          return UserRole.user;
      }
    } else {
      return UserRole.user; // 默认为普通用户
    }
  }

  // 安全解析方法，失败时返回null
  static ParticipantMetadata? tryParse(dynamic metadata) {
    if (metadata == null) return null;

    try {
      if (metadata is String) {
        Map<String, dynamic> metadataMap = json.decode(metadata);
        return ParticipantMetadata.fromJson(metadataMap);
      } else if (metadata is Map) {
        Map<String, dynamic> metadataMap =
            Map<String, dynamic>.from(metadata as Map);
        return ParticipantMetadata.fromJson(metadataMap);
      }
    } catch (e) {
      // 解析失败时返回null
      return null;
    }

    return null;
  }

  factory ParticipantMetadata.fromJson(Map<String, dynamic> json) {
    // 从nickname获取用户名
    String? userName = json['nickname'] as String?;

    return ParticipantMetadata(
      role: _roleFromString(json['role']),
      hand_raised: json['hand_raised'] as bool? ?? false,
      invited_to_stage: json['invited_to_stage'] as bool? ?? false,
      user_id: json['user_id'] as String? ?? json['identity'] as String?,
      user_name: userName, // 使用nickname值
      faceURL: json['faceURL'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role.toString().split('.').last,
      'hand_raised': hand_raised,
      'user_id': user_id,
      'user_name': user_name,
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  // 获取角色标签（中文）
  String getRoleLabel() {
    switch (role) {
      case UserRole.owner:
        return StrRes.meetingRoleHost;
      case UserRole.admin:
        return StrRes.meetingRoleAdmin;
      case UserRole.publisher:
        return StrRes.meetingRolePublisher;
      case UserRole.user:
        return StrRes.meetingRoleAudience;
    }
  }

  // 获取角色对应的颜色
  Color getRoleColor() {
    switch (role) {
      case UserRole.owner:
        return Colors.red;
      case UserRole.admin:
        return Colors.orange;
      case UserRole.publisher:
        return Colors.blue;
      case UserRole.user:
        return Colors.grey;
    }
  }
}

class MeetingLogic extends GetxController with WidgetsBindingObserver {
  // 会议信息
  final meetingTitle = ''.obs;
  final meetingCover = ''.obs; // 会议封面图片
  final meetingDuration = '00:00:00'.obs;
  final participantCount = 0.obs;
  final isHost = false.obs; // 是否为主持人
  // 会议创建时间
  DateTime? _meetingCreateTime;

  // 用户信息
  final currentUserName = ''.obs;
  final currentUserId = '123456'.obs;

  // 连接参数
  String? _wsUrl;
  String? _token;

  // 参与者
  final localParticipant = Rxn<lk.LocalParticipant>();
  final remoteParticipants = <lk.RemoteParticipant>[].obs;
  final screenShareParticipant = Rxn<lk.RemoteParticipant>();
  // 存储没有视频轨道的重要角色参与者
  final importantParticipantsWithoutTracks = <lk.RemoteParticipant>[].obs;
  // 跟踪手动添加的用户和添加时间，防止短时间内被移除
  final Map<String, DateTime> manuallyAddedParticipants = {};

  // 存储各参与者的语音活动状态 - 用于显示说话边框
  final speakingParticipants = <String, double>{}.obs;

  // 设备状态
  final isMuted = false.obs;
  final isCameraOff = false.obs;
  final isScreenSharing = false.obs;
  final hasRaisedHand = false.obs;
  final isShowingChatInput = false.obs; // 是否显示聊天输入框

  // 聊天
  final messages = <ChatMessage>[].obs;
  final messageController = TextEditingController();

  // 举手请求
  final raisedHands = <RaisedHandRequest>[].obs;

  // 会议房间和轨道
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _roomListener;

  // 远程视频轨道流 - 使用RxList存储用于UI展示的远程轨道
  final remoteTracks = <lk.TrackPublication>[].obs;

  // 屏幕共享轨道
  final screenShareTrack = Rxn<lk.TrackPublication>();
  final apiService = core.ApiService();

  // 计时器
  Timer? _durationTimer;
  int _durationInSeconds = 0;

  // 添加UI更新计数器
  final updateCounter = 0.obs;

  // 摄像头控制
  // 摄像头选择（前置/后置）
  final isFrontCamera = true.obs;

  @override
  void onInit() {
    super.onInit();
    
    // 注册应用生命周期监听
    WidgetsBinding.instance.addObserver(this);

    final args = Get.arguments;
    if (args != null) {
      // 设置会议标题和信息
      if (args['liveStreamName'] != null) {
        meetingTitle.value = args['liveStreamName'];
      }

      // 设置是否为主持人
      if (args['isHost'] != null) {
        isHost.value = args['isHost'];
      }

      // 设置设备状态
      if (args['isHost'] == true) {
        // 房主根据传入参数设置音视频状态
        isCameraOff.value = args['isCameraEnabled'] == true ? false : true;
        isMuted.value = args['isMicrophoneEnabled'] == true ? false : true;
        
        // 设置摄像头方向
        if (args['isFrontCamera'] != null) {
          isFrontCamera.value = args['isFrontCamera'];
        }
      } else {
        // 非房主默认关闭
        isCameraOff.value = true;
        isMuted.value = true;
      }

      // 设置房间参数
      _wsUrl = args['wsUrl'];
      _token = args['token'];

      if (_wsUrl != null && _token != null) {
        ILogger.d('MeetingLogic', '连接参数: wsUrl=$_wsUrl, token=$_token');
      }
    }

    _initMeeting();
    
    // 监听localParticipant的变化
    ever(localParticipant, (_) {
      // 强制刷新工具栏
      update();
    });
  }

  @override
  void onClose() {
    // 移除应用生命周期监听
    WidgetsBinding.instance.removeObserver(this);
    
    _durationTimer?.cancel();
    messageController.dispose();
    _disconnectRoom();
    // 清理举手请求
    for (final request in raisedHands) {
      request.dispose();
    }
    _roomListener?.dispose();
    super.onClose();
  }

  // 监听应用生命周期状态变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 只在房主且应用意外关闭时调用退出接口（不包括进入后台的情况）
    if (isHost.value && state == AppLifecycleState.detached) {
      ILogger.d('MeetingLogic', StrRes.liveHostAppExit);
      _executeEndMeeting();
    }
  }

  // 断开房间连接
  void _disconnectRoom() {
    _room?.disconnect();
  }

  // 请求必要的权限
  Future<void> _requestPermissions() async {
    try {
      // 请求摄像头和麦克风权限
      final mediaStream = await webrtc.navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': true});

      // 立即释放资源，我们只是为了获取权限
      mediaStream.getTracks().forEach((track) => track.stop());
    } catch (e) {
      ILogger.d('MeetingLogic', '请求媒体权限失败: $e');
    }
  }

  // 初始化会议
  void _initMeeting() {
    // 连接房间
    _connectToRoom();

  }

  // 开始计时器
  void _startTimers() {
    // 取消已有定时器
    _durationTimer?.cancel();

    // 创建单一定时器处理会议时长
    _durationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_meetingCreateTime != null) {
        // 使用服务器时间
        _updateDurationFromCreateTime();
      } else {
        // 使用本地计时
        _durationInSeconds++;
        final hours = (_durationInSeconds ~/ 3600).toString().padLeft(2, '0');
        final minutes =
            ((_durationInSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
        final seconds = (_durationInSeconds % 60).toString().padLeft(2, '0');
        meetingDuration.value = '$hours:$minutes:$seconds';
      }
    });
  }

  // 静默更新参与者数量，不触发视图刷新
  void _updateParticipantCountSilent() {
    if (_room == null) return;

    // 计算所有参与者数量（本地+远程）
    final localCount = localParticipant.value != null ? 1 : 0;
    final remoteCount = _room!.remoteParticipants.length;
    final newCount = localCount + remoteCount;

    // 只有当计数发生变化时才更新，避免不必要的UI刷新
    if (participantCount.value != newCount) {
      participantCount.value = newCount;
    }
  }

  // 仅更新远程轨道数据，不强制刷新整个UI
  void _updateRemoteTracksDataOnly() {
    // 存储要显示的轨道
    List<lk.TrackPublication> tracks = [];
    // 存储重要角色但没有视频轨道的参与者
    List<lk.RemoteParticipant> importantRolesWithoutTracks = [];
    
    // 跟踪已处理的参与者ID，防止同一参与者添加多个轨道
    final Set<String> processedParticipantIds = {};

    // 处理每一个远程参与者
    for (final participant in remoteParticipants) {
      // 如果该参与者已被处理，跳过
      if (processedParticipantIds.contains(participant.identity)) {
        continue;
      }
      
      // 检查参与者角色
      UserRole participantRole = UserRole.user;

      try {
        if (participant.metadata != null) {
          // 解析参与者元数据
          ParticipantMetadata? metadata;
          if (participant.metadata is String) {
            Map<String, dynamic> metadataMap =
                json.decode(participant.metadata!);
            metadata = ParticipantMetadata.fromJson(metadataMap);
          } else if (participant.metadata is Map) {
            Map<String, dynamic> metadataMap =
                Map<String, dynamic>.from(participant.metadata as Map);
            metadata = ParticipantMetadata.fromJson(metadataMap);
          }

          if (metadata != null) {
            participantRole = metadata.role;
          }
        }
      } catch (e) {
        ILogger.e('MeetingLogic', '解析参与者元数据失败: $e');
      }

      // 判断是否为重要角色（非普通用户）
      bool hasRole = participantRole != UserRole.user;

      lk.TrackPublication? videoTrackPub;
      bool isScreenShare = false;
      bool hasVideoTrack = false;

      // 遍历参与者的所有轨道
      for (final pub in participant.trackPublications.values) {
        // 处理屏幕共享轨道
        if (pub.source == lk.TrackSource.screenShareVideo &&
            pub.kind == lk.TrackType.VIDEO) {
          // 更新屏幕共享数据，但避免引起整个UI重建
          final currentTrack = screenShareTrack.value;
          if (currentTrack == null || currentTrack.sid != pub.sid) {
            screenShareTrack.value = pub;
            screenShareParticipant.value = participant;
          }
          isScreenShare = true;
          continue;
        }

        // 处理普通视频轨道
        if (pub.kind == lk.TrackType.VIDEO &&
            pub.source != lk.TrackSource.screenShareVideo) {
          videoTrackPub = pub;
          hasVideoTrack = true;

          // 如果视频轨道已订阅且有效，添加到轨道列表
          if (pub.subscribed && pub.track != null) {
            // 标记该参与者ID已处理，防止再次添加
            processedParticipantIds.add(participant.identity);
            tracks.add(pub);
            break; // 找到有效轨道后不再继续查找
          }
        }
      }

      // 简化逻辑：如果是重要角色且有视频轨道（即使未激活），也添加到列表中
      if (!processedParticipantIds.contains(participant.identity)) {
        if (hasRole && videoTrackPub != null) {
          processedParticipantIds.add(participant.identity);
          tracks.add(videoTrackPub);
        } else if (hasRole && !hasVideoTrack) {
          // 如果是重要角色但没有视频轨道，添加到无轨道列表
          processedParticipantIds.add(participant.identity);
          importantRolesWithoutTracks.add(participant);
        }
      }
    }

    // 比较并有选择地更新，避免不必要的UI刷新
    bool importantTracksChanged =
        _haveImportantTracksChanged(importantRolesWithoutTracks);
    bool tracksChanged = _haveTracksChanged(tracks);

    if (importantTracksChanged) {
      importantParticipantsWithoutTracks.assignAll(importantRolesWithoutTracks);
    }

    if (tracksChanged) {
      remoteTracks.assignAll(tracks);
    }
  }

  // 检查重要参与者列表是否有变化
  bool _haveImportantTracksChanged(List<lk.RemoteParticipant> newList) {
    if (importantParticipantsWithoutTracks.length != newList.length)
      return true;

    // 逐个比较ID
    for (int i = 0; i < newList.length; i++) {
      bool found = false;
      for (int j = 0; j < importantParticipantsWithoutTracks.length; j++) {
        if (importantParticipantsWithoutTracks[j].identity ==
            newList[i].identity) {
          found = true;
          break;
        }
      }
      if (!found) return true;
    }

    return false;
  }

  // 检查轨道列表是否有变化
  bool _haveTracksChanged(List<lk.TrackPublication> newList) {
    if (remoteTracks.length != newList.length) return true;

    // 逐个比较SID
    for (int i = 0; i < newList.length; i++) {
      bool found = false;
      for (int j = 0; j < remoteTracks.length; j++) {
        if (remoteTracks[j].sid == newList[i].sid) {
          found = true;
          break;
        }
      }
      if (!found) return true;
    }

    return false;
  }

  // 修改原始强制刷新方法，仅在必要情况下调用
  void _forceRefreshRoom() {
    if (_room == null) return;

    try {
      // 刷新远程参与者列表
      remoteParticipants.clear();
      remoteParticipants.addAll(_room!.remoteParticipants.values.toList());

      // 手动尝试订阅所有未订阅的轨道
      for (var participant in _room!.remoteParticipants.values) {
        for (var pub in participant.trackPublications.values) {
          // 只处理视频轨道
          if (pub.kind == lk.TrackType.VIDEO && !pub.subscribed) {
            try {
              pub.subscribe();
            } catch (e) {
              ILogger.e('MeetingLogic', '订阅轨道失败: $e');
            }
          }
        }
      }

      // 更新UI，但不使用update()
      _updateParticipantCountSilent();
      _updateRemoteTracksDataOnly();

      // 仅当明确需要完全刷新UI时，才增加计数器值触发更新
      updateCounter.value++;
    } catch (e) {
      ILogger.e('MeetingLogic', '强制刷新房间失败: $e');
    }
  }

  // 连接到房间
  Future<void> _connectToRoom() async {
    try {
      // 请求必要的权限
      await _requestPermissions();

      // 使用传递的房间参数或使用默认值
      final url = _wsUrl ?? 'wss://livekit-server-url';
      final token = _token ?? 'default-token';

      // 设置日志级别
      // lk.Logger.level = lk.LogLevel.info;

      // 创建Room实例
      _room = lk.Room();

      // 设置房间事件监听
      _setupRoomListeners();

      // 连接到房间
      await _room!.connect(
        url,
        token,
          roomOptions: lk.RoomOptions(
          dynacast: true,
          adaptiveStream: true,
          defaultCameraCaptureOptions: lk.CameraCaptureOptions(
            params: lk.VideoParametersPresets.h720_169,
          ),
          defaultVideoPublishOptions: lk.VideoPublishOptions(
            simulcast: true,
            videoCodec: 'VP9',
            videoEncoding: lk.VideoEncoding(
              maxBitrate: 3 * 1000 * 1000,  // 3 Mbps适合直播
              maxFramerate: 30,              // 30 fps提供更流畅体验
            ),
          ),
        ),
        connectOptions: const lk.ConnectOptions(
          autoSubscribe: true,
        ),
      );

      // 获取本地参与者
      localParticipant.value = _room!.localParticipant;


      // 更新用户名和ID
      try {
        if (_room!.localParticipant?.metadata != null) {
          // 解析元数据
          var metadata = _room!.localParticipant?.metadata;
          Map<String, dynamic> metadataMap;

          if (metadata is String) {
            // 如果是字符串格式，解析JSON
            metadataMap = json.decode(metadata);
          } else if (metadata is Map) {
            // 如果已经是Map格式
            metadataMap = Map<String, dynamic>.from(metadata as Map);
          } else {
            throw Exception(StrRes.meetingErrorMetadataFormat);
          }

          
          // 从元数据中获取nickname
          if (metadataMap.containsKey('nickname') &&
              metadataMap['nickname'] != null &&
              metadataMap['nickname'].toString().isNotEmpty) {
            currentUserName.value = metadataMap['nickname'];
          } else {
            // 如果没有nickname，使用identity
            currentUserName.value =
                _room!.localParticipant?.identity ?? currentUserName.value;
          }
          // 从元数据中获取create_at并更新会议时长
        } else {
          // 如果没有元数据，使用identity
          currentUserName.value =
              _room!.localParticipant?.identity ?? currentUserName.value;
        }
      } catch (e) {
        // 发生错误时的处理
        currentUserName.value =
            _room!.localParticipant?.identity ?? currentUserName.value;
      }
      currentUserId.value =
          _room!.localParticipant?.identity ?? currentUserId.value;

      // 根据角色配置本地媒体
      await _configureLocalMedia();
      await Future.delayed(Duration(milliseconds: 500)); // 添加短暂延迟

      // 更新参与者数量
      _updateParticipantCount();


      // 添加安全检查，并记录metadata类型
      if (_room!.metadata != null) {
        ILogger.d('MeetingLogic', '房间元数据类型: ${_room!.metadata.runtimeType}');
        
                  try {
            // 尝试解析房间元数据
            String? createAtString;
            String? roomTitle;
            String? roomCover;
            
            if (_room!.metadata is String) {
              // 如果是字符串，尝试解析为JSON
              try {
                Map<String, dynamic> metadataMap = json.decode(_room!.metadata as String);
                createAtString = metadataMap['create_at']?.toString();
                roomTitle = metadataMap['nickname']?.toString();
                roomCover = metadataMap['cover']?.toString();
              } catch (e) {
                ILogger.e('MeetingLogic', '解析String类型元数据失败: $e');
              }
            } else if (_room!.metadata is Map) {
              // 如果是Map，直接尝试获取
              try {
                final metadataMap = _room!.metadata as Map;
                createAtString = metadataMap['create_at']?.toString();
                roomTitle = metadataMap['nickname']?.toString();
                roomCover = metadataMap['cover']?.toString();
              } catch (e) {
                ILogger.e('MeetingLogic', '从Map获取元数据失败: $e');
              }
            }
            
            // 设置房间标题
            if (roomTitle != null && roomTitle.isNotEmpty) {
              meetingTitle.value = roomTitle;
              ILogger.d('MeetingLogic', '从房间元数据获取到标题: $roomTitle');
            }
            
            // 设置房间封面
            if (roomCover != null && roomCover.isNotEmpty) {
              meetingCover.value = roomCover;
              ILogger.d('MeetingLogic', '从房间元数据获取到封面: $roomCover');
            }
          
          // 处理获取到的createAtString
          if (createAtString != null && createAtString.isNotEmpty) {
            _meetingCreateTime = DateTime.parse(createAtString);
            _updateDurationFromCreateTime();
            
            // 启动基于服务器时间的计时器
            _startTimers();
          } else {
            // 如果没有获取到create_at，启动基于本地时间的计时器
            _startTimers();
          }
        } catch (e) {
          ILogger.e('MeetingLogic', '解析房间元数据失败: $e');
        }
      }


      // 添加欢迎消息
      _addSystemMessage('${StrRes.welcomeToJoin}${meetingTitle.value}');

      // 连接成功后，先延迟1秒，确保服务器状态同步
      Future.delayed(Duration(seconds: 1), () {
        // 强制刷新轨道和参与者列表
        _forceRefreshRoom();
      });

      // 再延迟3秒进行二次刷新
      Future.delayed(Duration(seconds: 3), () {
        _forceRefreshRoom();
      });

      // 订阅房间状态变化，当有任何参与者加入/离开时更新UI
      _room!.remoteParticipants.forEach((_, participant) {
        // 尝试订阅所有参与者轨道
        participant.trackPublications.forEach((_, pub) {
          if (pub.kind == lk.TrackType.VIDEO && !pub.subscribed) {
            try {
              pub.subscribe();
            } catch (e) {
              ILogger.e('MeetingLogic', '订阅轨道失败: $e');
            }
          }
        });
      });
    } catch (e) {
      ILogger.e('MeetingLogic', '初始化会议失败: $e');
    }
  }

  // 设置房间监听器
  void _setupRoomListeners() {
    _roomListener?.dispose();

    _roomListener = _room!.createListener();

    // 监听参与者连接/断开事件
    _roomListener!.on<lk.ParticipantConnectedEvent>(
        (event) => _onParticipantConnected(event.participant));
    _roomListener!.on<lk.ParticipantDisconnectedEvent>(
        (event) => _onParticipantDisconnected(event.participant));

    // 监听本地轨道发布事件
    _roomListener!.on<lk.LocalTrackPublishedEvent>(
        (event) => _onLocalTrackPublished(event.publication));
    _roomListener!.on<lk.LocalTrackUnpublishedEvent>(
        (event) => _onLocalTrackUnpublished(event.publication));

    // 监听远程轨道发布/订阅事件
    _roomListener!.on<lk.TrackPublishedEvent>(
        (event) => _onTrackPublished(event.publication, event.participant));
    _roomListener!.on<lk.TrackSubscribedEvent>((event) =>
        _onTrackSubscribed(event.track, event.publication, event.participant));
    _roomListener!.on<lk.TrackUnsubscribedEvent>((event) =>
        _onTrackUnsubscribed(
            event.track, event.publication, event.participant));

    // 新增: 直接监听轨道状态变化事件
    _roomListener!.on<lk.TrackMutedEvent>((event) {
      // 当视频轨道被静音时更新UI
      if (event.publication.kind == lk.TrackType.VIDEO) {
        ILogger.d('MeetingLogic', '视频轨道已静音: ${event.publication.sid}');
        updateCounter.value++;
      }
    });

    _roomListener!.on<lk.TrackUnmutedEvent>((event) {
      // 当视频轨道取消静音时更新UI
      if (event.publication.kind == lk.TrackType.VIDEO) {
        ILogger.d('MeetingLogic', '视频轨道已取消静音: ${event.publication.sid}');
        updateCounter.value++;
      }
    });

    // 添加活跃说话者监听
    _roomListener!.on<lk.ActiveSpeakersChangedEvent>((event) {
      _handleActiveSpeakersChanged(event.speakers);
    });

    // 添加参与者说话状态变化监听
    _roomListener!.on<lk.SpeakingChangedEvent>((event) {
      _handleSpeakingChanged(event.participant, event.speaking);
    });

    // 参与者元数据更新
    _roomListener!.on<lk.ParticipantMetadataUpdatedEvent>(
        (event) => _onParticipantMetadataUpdated(event.participant));

    // 监听房间事件
    _roomListener!
        .on<lk.RoomDisconnectedEvent>((event) => _onRoomDisconnected(event));

    // 监听参与者连接质量变化
    _roomListener!.on<lk.ParticipantConnectionQualityUpdatedEvent>((event) {
      // 连接质量变化事件
      ILogger.d('MeetingLogic',
          '参与者连接质量更新: ${event.participant.identity}, 质量: ${event.connectionQuality}');
    });

    // 监听数据接收事件
    _roomListener!.on<lk.DataReceivedEvent>((event) {
      _onDataReceived(
          Uint8List.fromList(event.data), event.participant, event.topic);
    });

    // 监听房间元数据更新事件
    _roomListener!.on<lk.RoomMetadataChangedEvent>((event) {
      _onRoomMetadataChanged(event);
    });
  }

  // 处理活跃说话者变化事件
  void _handleActiveSpeakersChanged(List<lk.Participant> speakers) {
    // 清除当前的说话参与者列表
    speakingParticipants.clear();

    // 如果没有活跃说话者，直接返回
    if (speakers.isEmpty) {
      updateCounter.value++; // 触发UI更新
      return;
    }

    // 按音量倒序排列说话者(假设列表已按音量排序)
    for (int i = 0; i < speakers.length; i++) {
      final participant = speakers[i];
      // 计算音量值(0.3-1.0)，活跃度越高(排名越靠前)分配的音量值越大
      final volumeLevel = 0.3 + ((speakers.length - i) / speakers.length) * 0.7;
      // 更新说话状态映射
      speakingParticipants[participant.identity] = volumeLevel;
    }

    // 触发UI更新
    updateCounter.value++;

    ILogger.d('MeetingLogic', '活跃说话者更新: ${speakers.length}人在说话');
  }

  // 处理参与者说话状态变化事件
  void _handleSpeakingChanged(lk.Participant participant, bool speaking) {
    if (speaking) {
      // 参与者开始说话
      speakingParticipants[participant.identity] = 0.6; // 设置初始音量
      ILogger.d('MeetingLogic', '参与者开始说话: ${participant.identity}');
    } else {
      // 参与者停止说话
      speakingParticipants.remove(participant.identity);
      ILogger.d('MeetingLogic', '参与者停止说话: ${participant.identity}');
    }

    // 触发UI更新
    updateCounter.value++;
  }

  // 配置本地媒体
  Future<void> _configureLocalMedia() async {
    if (_room?.localParticipant == null) return;

    try {
      // 根据当前状态设置麦克风
      await _room!.localParticipant!.setMicrophoneEnabled(!isMuted.value);

      // 根据当前状态设置摄像头，使用初始化时的前置/后置设置
      if (!isCameraOff.value) {
        try {
          // 先确保摄像头关闭
          await _room!.localParticipant!.setCameraEnabled(false);
          await Future.delayed(Duration(milliseconds: 300));

          // 创建摄像头轨道，根据isFrontCamera设置前置或后置摄像头
          final videoTrack = await lk.LocalVideoTrack.createCameraTrack(
              lk.CameraCaptureOptions(
            cameraPosition: isFrontCamera.value
                ? lk.CameraPosition.front
                : lk.CameraPosition.back,
          ));

          // 发布新创建的轨道
          await _room!.localParticipant!.publishVideoTrack(videoTrack);

          ILogger.d(
              'MeetingLogic', '初始化摄像头为${isFrontCamera.value ? "前置" : "后置"}摄像头');
        } catch (e) {
          // 如果特定摄像头初始化失败，尝试使用默认方法
          ILogger.e('MeetingLogic', '使用特定摄像头失败，回退到默认方法: $e');
          await _room!.localParticipant!.setCameraEnabled(true);
        }
      } else {
        // 如果摄像头应该关闭，确保它是关闭的
        await _room!.localParticipant!.setCameraEnabled(false);
      }

      // 强制刷新UI
      Future.delayed(Duration(milliseconds: 500), () {
        if (localParticipant.value != null) {
          _updateRemoteTracks();
          update(); // 确保UI更新
        }
      });
    } catch (e) {
      ILogger.e('MeetingLogic', '配置本地媒体失败: $e');
    }
  }

  // 更新参与者数量
  void _updateParticipantCount() {
    if (_room == null) return;

    // 计算所有参与者数量（本地+远程）
    final localCount = localParticipant.value != null ? 1 : 0;
    final remoteCount = _room!.remoteParticipants.length;
    final newCount = localCount + remoteCount;

    // 只有当计数发生变化时才更新，避免不必要的UI刷新
    if (participantCount.value != newCount) {
      participantCount.value = newCount;

      // 如果参与者数量变化，可能需要刷新视图
      if (remoteCount > 0) {
        _updateRemoteTracks();
        update();
      }
    }
  }

  // 本地轨道发布
  void _onLocalTrackPublished(lk.LocalTrackPublication publication) {
    // 如果是屏幕共享，更新屏幕共享状态
    if (publication.source == lk.TrackSource.screenShareVideo) {
      isScreenSharing.value = true;
    }
  }

  // 本地轨道取消发布
  void _onLocalTrackUnpublished(lk.LocalTrackPublication publication) {
    // 如果是屏幕共享，更新屏幕共享状态
    if (publication.source == lk.TrackSource.screenShareVideo) {
      isScreenSharing.value = false;
    }
  }

  // 参与者连接
  void _onParticipantConnected(lk.RemoteParticipant participant) {
    // 添加到远程参与者列表
    remoteParticipants.add(participant);

    // 尝试解析参与者元数据并记录角色
    try {
      if (participant.metadata != null) {
        ParticipantMetadata? metadata;
        if (participant.metadata is String) {
          Map<String, dynamic> metadataMap = json.decode(participant.metadata!);
          metadata = ParticipantMetadata.fromJson(metadataMap);
        } else if (participant.metadata is Map) {
          Map<String, dynamic> metadataMap =
              Map<String, dynamic>.from(participant.metadata as Map);
          metadata = ParticipantMetadata.fromJson(metadataMap);
        }

        if (metadata != null) {
          // 如果是重要角色，立即刷新视频轨道
          if (metadata.role != UserRole.user) {
            ILogger.d('MeetingLogic', '新连接的参与者是重要角色，立即刷新视频轨道');
          }
        }
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '解析新连接参与者元数据失败: $e');
    }

    // 更新UI
    _updateParticipantCount();

    // 添加系统消息
    try {
      String displayName = participant.identity;
      if (participant.metadata != null) {
        Map<String, dynamic> metadataMap;
        if (participant.metadata is String) {
          metadataMap = json.decode(participant.metadata!);
          displayName = metadataMap['nickname'] ?? participant.identity;
        } else if (participant.metadata is Map) {
          metadataMap = Map<String, dynamic>.from(participant.metadata as Map);
          displayName = metadataMap['nickname'] ?? participant.identity;
        }
      }

      _addSystemMessage('${displayName} ${StrRes.meetingStatusJoined}');
    } catch (e) {
      // 出错时使用原始ID
      _addSystemMessage('${participant.identity} ${StrRes.meetingStatusJoined}');
    }

    _updateRemoteTracks();
  }

  // 参与者断开连接
  void _onParticipantDisconnected(lk.RemoteParticipant participant) {
    // 从远程参与者列表中移除
    remoteParticipants.removeWhere((p) => p.identity == participant.identity);

    // 如果是屏幕共享参与者，清除屏幕共享
    if (screenShareParticipant.value?.identity == participant.identity) {
      screenShareParticipant.value = null;
      screenShareTrack.value = null;
    }

    // 增加计数器值触发UI刷新
    updateCounter.value++;

    // 更新参与者数量
    _updateParticipantCount();

    // 更新远程轨道列表
    _updateRemoteTracks();

    // 添加系统消息
    try {
      String displayName = participant.identity;
      if (participant.metadata != null) {
        Map<String, dynamic> metadataMap;
        if (participant.metadata is String) {
          metadataMap = json.decode(participant.metadata!);
          displayName = metadataMap['nickname'] ?? participant.identity;
        } else if (participant.metadata is Map) {
          metadataMap = Map<String, dynamic>.from(participant.metadata as Map);
          displayName = metadataMap['nickname'] ?? participant.identity;
        }
      }

      _addSystemMessage('${displayName} ${StrRes.meetingStatusLeft}');
    } catch (e) {
      // 出错时使用原始ID
      _addSystemMessage('${participant.identity} ${StrRes.meetingStatusLeft}');
    }
  }

  // 远程轨道发布
  void _onTrackPublished(
      lk.RemoteTrackPublication publication, lk.RemoteParticipant participant) {
    // 检查是否是屏幕共享轨道
    final bool isScreenShare =
        publication.source == lk.TrackSource.screenShareVideo;

    if (isScreenShare && publication.kind == lk.TrackType.VIDEO) {
      screenShareParticipant.value = participant;
      if (publication.subscribed) {
        screenShareTrack.value = publication;
      }
    }

    // 更新远程轨道列表
    _updateRemoteTracks();

    // 立即触发UI更新，确保摄像头状态变化能即时反映
    updateCounter.value++;
  }

  // 远程轨道订阅
  void _onTrackSubscribed(lk.Track track, lk.RemoteTrackPublication publication,
      lk.RemoteParticipant participant) {
    // 检查是否是屏幕共享轨道
    final bool isScreenShare =
        publication.source == lk.TrackSource.screenShareVideo;

    if (isScreenShare && publication.kind == lk.TrackType.VIDEO) {
      screenShareParticipant.value = participant;
      screenShareTrack.value = publication;
    }

    // 更新远程轨道列表
    _updateRemoteTracks();

    // 立即触发UI更新
    if (publication.kind == lk.TrackType.VIDEO) {
     
      updateCounter.value++;
    }
  }

  // 远程轨道取消订阅
  void _onTrackUnsubscribed(lk.Track track,
      lk.RemoteTrackPublication publication, lk.RemoteParticipant participant) {
    // 如果是屏幕共享轨道，清除屏幕共享
    if (screenShareTrack.value?.sid == publication.sid) {
      screenShareTrack.value = null;
    }

    // 更新远程轨道列表
    _updateRemoteTracks();

    // 立即触发UI更新
    if (publication.kind == lk.TrackType.VIDEO) {
          updateCounter.value++;
    }
  }

  // 处理接收的数据
  void _onDataReceived(
      Uint8List data, lk.RemoteParticipant? participant, String? topic) {
    try {
      final jsonString = utf8.decode(data);
      final jsonData = jsonDecode(jsonString);

      // 处理Web端格式的消息（有id和message字段）
      if (jsonData['id'] != null && jsonData['message'] != null) {
        // 获取发送者名称
        String senderName = '';

        // 1. 优先使用nickname字段
        if (jsonData['nickname'] != null &&
            jsonData['nickname'].toString().isNotEmpty) {
          senderName = jsonData['nickname'].toString();
        }
        // 2. 从participant元数据中获取nickname
        else if (participant?.metadata != null) {
          try {
            Map<String, dynamic> metadataMap;
            if (participant!.metadata is String) {
              metadataMap = json.decode(participant.metadata!);
            } else if (participant.metadata is Map) {
              metadataMap =
                  Map<String, dynamic>.from(participant.metadata as Map);
            } else {
              metadataMap = {};
            }
            senderName = metadataMap['nickname'] ?? participant.identity;
          } catch (e) {
            senderName = participant?.identity ?? StrRes.meetingUserUnknown;
          }
        } else {
          senderName = participant?.identity ?? StrRes.meetingUserUnknown;
        }

        final content = jsonData['message'].toString();

        // 确定用户角色
        String role = StrRes.meetingRoleAudience;
        if (participant != null) {
          try {
            if (participant.metadata != null) {
              // 解析角色
              Map<String, dynamic> metadataMap;
              if (participant.metadata is String) {
                metadataMap = json.decode(participant.metadata!);
              } else if (participant.metadata is Map) {
                metadataMap =
                    Map<String, dynamic>.from(participant.metadata as Map);
              } else {
                metadataMap = {};
              }

              if (metadataMap.containsKey('role')) {
                var roleData = metadataMap['role'];
                if (roleData is Map && roleData.containsKey('name')) {
                  String roleName = roleData['name'].toString().toLowerCase();
                  role = _getRoleName(roleName);
                } else if (roleData is String) {
                  role = _getRoleName(roleData.toLowerCase());
                }
              }
            }
          } catch (e) {
            // 解析失败使用默认角色
          }
        }

        // 添加到消息列表
        messages.add(ChatMessage(
          sender: senderName,
          content: content,
          role: role,
          timestamp: DateTime.now(),
          faceURL: _getFaceURLFromParticipant(participant),
        ));
      }
      // 检查旧格式消息类型
      else if (jsonData['type'] == 'hand_raise') {
        // 处理举手请求
        final user_id = jsonData['user_id'] ?? participant?.identity ?? '';
        final user_name =
            jsonData['user_name'] ?? participant?.identity ?? StrRes.meetingUserUnknown;

        // 添加到举手列表
        _addRaisedHandRequest(user_id, user_name);
      } else if (jsonData['type'] == 'hand_lower') {
        // 处理取消举手
        final user_id = jsonData['user_id'] ?? participant?.identity ?? '';

        // 从举手列表中移除
        _removeRaisedHandRequest(user_id);
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '处理数据消息失败: $e');
    }
  }

  // 从参与者获取头像URL
  String? _getFaceURLFromParticipant(lk.RemoteParticipant? participant) {
    if (participant?.metadata == null) return null;

    try {
      Map<String, dynamic> metadataMap;
      if (participant!.metadata is String) {
        metadataMap = json.decode(participant.metadata!);
      } else if (participant.metadata is Map) {
        metadataMap = Map<String, dynamic>.from(participant.metadata as Map);
      } else {
        return null;
      }

      return metadataMap['faceURL'] as String?;
    } catch (e) {
      ILogger.e('MeetingLogic', '获取参与者头像URL失败: $e');
      return null;
    }
  }

  // 辅助方法：根据角色ID获取角色名称
  String _getRoleName(String roleId) {
    switch (roleId) {
      case 'owner':
        return StrRes.meetingRoleHost;
      case 'admin':
        return StrRes.meetingRoleAdmin;
      case 'publisher':
        return StrRes.meetingRolePublisher;
      case 'user':
      default:
        return StrRes.meetingRoleAudience;
    }
  }

  // 更新远程轨道列表
  void _updateRemoteTracks() {
    // 存储要显示的轨道
    List<lk.TrackPublication> tracks = [];
    // 存储重要角色但没有视频轨道的参与者
    List<lk.RemoteParticipant> importantRolesWithoutTracks = [];
    
    // 跟踪已处理的参与者ID，防止同一参与者添加多个轨道
    final Set<String> processedParticipantIds = {};

    // 处理每一个远程参与者
    for (final participant in remoteParticipants) {
      // 如果该参与者已被处理，跳过
      if (processedParticipantIds.contains(participant.identity)) {
        continue;
      }
      
      // 检查参与者角色
      UserRole participantRole = UserRole.user;

      try {
        if (participant.metadata != null) {
          // 解析参与者元数据
          ParticipantMetadata? metadata;
          if (participant.metadata is String) {
            Map<String, dynamic> metadataMap =
                json.decode(participant.metadata!);
            metadata = ParticipantMetadata.fromJson(metadataMap);
          } else if (participant.metadata is Map) {
            Map<String, dynamic> metadataMap =
                Map<String, dynamic>.from(participant.metadata as Map);
            metadata = ParticipantMetadata.fromJson(metadataMap);
          }

          if (metadata != null) {
            participantRole = metadata.role;
          }
        }
      } catch (e) {
        ILogger.e('MeetingLogic', '解析参与者元数据失败: $e');
      }

      // 判断是否为重要角色（非普通用户）
      bool hasRole = participantRole != UserRole.user;

      lk.TrackPublication? videoTrackPub;
      bool isScreenShare = false;
      bool hasVideoTrack = false;

      // 遍历参与者的所有轨道
      for (final pub in participant.trackPublications.values) {
        // 处理屏幕共享轨道
        if (pub.source == lk.TrackSource.screenShareVideo &&
            pub.kind == lk.TrackType.VIDEO) {
          // 更新屏幕共享数据，但避免引起整个UI重建
          final currentTrack = screenShareTrack.value;
          if (currentTrack == null || currentTrack.sid != pub.sid) {
            screenShareTrack.value = pub;
            screenShareParticipant.value = participant;
          }
          isScreenShare = true;
          continue;
        }

        // 处理普通视频轨道
        if (pub.kind == lk.TrackType.VIDEO &&
            pub.source != lk.TrackSource.screenShareVideo) {
          videoTrackPub = pub;
          hasVideoTrack = true;

          // 如果视频轨道已订阅且有效，添加到轨道列表
          if (pub.subscribed && pub.track != null) {
            // 标记该参与者ID已处理，防止再次添加
            processedParticipantIds.add(participant.identity);
            tracks.add(pub);
            break; // 找到有效轨道后不再继续查找
          }
        }
      }

      // 简化逻辑：如果是重要角色且有视频轨道（即使未激活），也添加到列表中
      if (!processedParticipantIds.contains(participant.identity)) {
        if (hasRole && videoTrackPub != null) {
          processedParticipantIds.add(participant.identity);
          tracks.add(videoTrackPub);
        } else if (hasRole && !hasVideoTrack) {
          // 如果是重要角色但没有视频轨道，添加到无轨道列表
          processedParticipantIds.add(participant.identity);
          importantRolesWithoutTracks.add(participant);
        }
      }
    }

    // 比较并有选择地更新，避免不必要的UI刷新
    bool importantTracksChanged =
        _haveImportantTracksChanged(importantRolesWithoutTracks);
    bool tracksChanged = _haveTracksChanged(tracks);

    if (importantTracksChanged) {
      importantParticipantsWithoutTracks.assignAll(importantRolesWithoutTracks);
    }

    if (tracksChanged) {
      remoteTracks.assignAll(tracks);
    }
  }

  // 房间断开连接
  void _onRoomDisconnected(lk.RoomDisconnectedEvent event) {
    _addSystemMessage(StrRes.meetingSystemDisconnected);

    //如果不是房主 被退出就返回
    if (!(isHost.value)) {
      Future.delayed(Duration(seconds: 1), () => Get.back());
    }
  }

  // 处理参与者元数据更新
  void _onParticipantMetadataUpdated(lk.Participant participant) {
 
    try {
      if (participant.metadata != null) {
        // 获取元数据
        final metadata = participant.metadata;

        // 创建元数据对象
        Map<String, dynamic> metadataMap;

        // 解析元数据
        try {
          if (metadata is String) {
            metadataMap = json.decode(metadata);
          } else if (metadata is Map) {
            metadataMap = Map<String, dynamic>.from(metadata as Map);
          } else {
            return;
          }
        } catch (parseError) {
          return;
        }

        // 获取角色数据 - 处理嵌套格式
        UserRole userRole = UserRole.user;
        bool isHandRaised = false;
        bool isInvitedToStage = false;
        String nickname = '';

        // 解析举手状态
        isHandRaised = metadataMap['hand_raised'] == true;

        // 解析被邀请上台状态
        isInvitedToStage = metadataMap['invited_to_stage'] == true;

        // 解析昵称
        nickname = metadataMap['nickname']?.toString() ?? participant.identity;

        // 解析角色 - 支持嵌套结构
        if (metadataMap.containsKey('role')) {
          var roleData = metadataMap['role'];
          if (roleData is Map) {
            String roleName =
                roleData['name']?.toString().toLowerCase() ?? 'user';

            switch (roleName) {
              case 'owner':
                userRole = UserRole.owner;
                break;
              case 'admin':
                userRole = UserRole.admin;
                break;
              case 'publisher':
                userRole = UserRole.publisher;
                break;
              case 'user':
              default:
                userRole = UserRole.user;
                break;
            }
          } else if (roleData is String) {
            // 向下兼容简单字符串角色
            String roleName = roleData.toLowerCase();
            switch (roleName) {
              case 'owner':
                userRole = UserRole.owner;
                break;
              case 'admin':
                userRole = UserRole.admin;
                break;
              case 'publisher':
                userRole = UserRole.publisher;
                break;
              case 'user':
              default:
                userRole = UserRole.user;
                break;
            }
          }
        }

    
        // 处理本地用户状态更新
        if (participant is lk.LocalParticipant &&
            participant == localParticipant.value) {
          // 更新举手状态
          hasRaisedHand.value = isHandRaised;

          // 更新房主状态
          isHost.value = userRole == UserRole.owner;

          // 判断是否由普通用户变为连麦者
          bool wasPublisher =
              userRole == UserRole.publisher || userRole == UserRole.admin;

          // 判断是否由连麦者变为普通用户(下麦)
          bool wasDowngraded = userRole == UserRole.user;

          if (wasPublisher) {
            // 移除举手状态
            hasRaisedHand.value = false;

            // 不自动开启麦克风和摄像头，保持当前状态
            localParticipant.value = null;
            Future.microtask(() {
              localParticipant.value = participant;

              // 强制刷新UI和参与者列表
              _updateRemoteTracks();
              _updateParticipantCount();
              update();

              // 根据用户角色显示不同的提示信息
              String title = '';
              String message = '';
              Color bgColor = Colors.green.withOpacity(0.7);

              switch (userRole) {
                case UserRole.admin:
                  title = StrRes.meetingStatusAdminGranted;
                  message = StrRes.meetingStatusAdminGrantedMsg;
                  bgColor = Colors.blue.withOpacity(0.7);
                  break;
                case UserRole.publisher:
                  title = StrRes.meetingStatusConnectedSuccess;
                  message = StrRes.meetingStatusConnectedSuccessMsg;
                  bgColor = Colors.green.withOpacity(0.7);
                  break;

                default:
                  return; // 如果是其他角色，不显示提示
              }

              // 显示提示信息
              Get.snackbar(
                title,
                message,
                snackPosition: SnackPosition.TOP,
                backgroundColor: bgColor,
                colorText: Colors.white,
              );
            });
          } else if (wasDowngraded) {
            // 处理被下麦的情况

            // 强制刷新本地参与者 - 使用先置空再赋值的方式确保Obx能检测到变化
            final originalParticipant = participant; // 保存原始引用
            localParticipant.value = null; // 先置空

            // 使用微任务确保先置空操作在UI中生效
            Future.microtask(() {
              localParticipant.value = originalParticipant; // 再赋值

              // 强制刷新UI
              _updateRemoteTracks();
              update();
            });
          }

          // 处理被邀请上台的情况 - 只添加消息，不弹框
          if (isInvitedToStage && userRole == UserRole.user) {
            // 添加系统消息
            _addSystemMessage(StrRes.meetingSystemHostInviteStage);

            // 弹出确认对话框
            Get.dialog(
              AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.mic, color: Colors.amber.shade700),
                    SizedBox(width: 8),
                    Text(StrRes.meetingUiInviteTitle),
                  ],
                ),
                content: Text(StrRes.meetingSystemHostInviteStage),
                actions: [
                  TextButton(
                    onPressed: () {
                      Get.back(); // 关闭对话框
                      rejectInvitation(); // 拒绝邀请
                    },
                    child: Text(StrRes.meetingUiReject, style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Get.back(); // 关闭对话框
                      acceptInvitation(); // 接受邀请
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text(StrRes.meetingUiAccept, style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              barrierDismissible: false, // 防止点击外部关闭
            );
          }
        }
        // 处理远程用户状态更新
        else if (participant is lk.RemoteParticipant) {
          // 处理远程参与者举手
          if (isHandRaised) {
            _addRaisedHandRequest(participant.identity,
                nickname.isNotEmpty ? nickname : participant.identity);
          } else {
            _removeRaisedHandRequest(participant.identity);
          }

          // 处理角色变化
          if (userRole != UserRole.user) {
            // 确保该参与者在remoteParticipants列表中
            if (!remoteParticipants.contains(participant)) {
              remoteParticipants.add(participant);
            }

            // 当参与者角色发生变化时，添加系统消息
            if (userRole == UserRole.publisher) {
              _addSystemMessage('${nickname} ${StrRes.meetingStatusConnectedSuccess}');
            }
          }

          // 更新远程轨道展示
          _updateRemoteTracks();

          // 刷新远程参与者列表以更新角色
          update();
        }
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '处理参与者元数据更新失败: $e');
    }
  }

  // 处理房间元数据变化
  void _onRoomMetadataChanged(lk.RoomMetadataChangedEvent event) {}

  // 添加举手请求
  void _addRaisedHandRequest(String user_id, String user_name) {
    // 检查是否已存在
    final exists = raisedHands.any((req) => req.user_id == user_id);
    if (!exists) {
      // 添加新请求
      raisedHands.add(RaisedHandRequest(
        user_id: user_id,
        user_name: user_name,
        timestamp: DateTime.now(),
      ));

      // 排序请求（最新的在前面）
      raisedHands.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // 添加系统消息
      _addSystemMessage('$user_name ${StrRes.meetingStatusHandRaised}');
    }
  }

  // 移除举手请求
  void _removeRaisedHandRequest(String user_id) {
    final index = raisedHands.indexWhere((req) => req.user_id == user_id);
    if (index != -1) {
      final request = raisedHands[index];
      final user_name = request.user_name;

      // 清理计时器
      request.dispose();

      // 移除请求
      raisedHands.removeAt(index);

      // 添加系统消息
      // _addSystemMessage('$user_name 取消了发言请求');
    }
  }

  // 添加系统消息
  void _addSystemMessage(String content) {
    final message = ChatMessage(
      sender: StrRes.meetingSystemSender,
      content: content,
      role: 'system',
      timestamp: DateTime.now(),
    );
    messages.add(message);
  }

  final uuid = Uuid();

  // 发送聊天消息
  void sendChatMessage() {
    final content = messageController.text.trim();
    if (content.isEmpty) return;

    try {
      // 创建消息数据
      final message = {
        'id': uuid.v4(),
        'message': content,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'nickname': currentUserName.value, // 添加nickname
        'ignore': false
      };

      // 转换为JSON并发送
      final jsonString = json.encode(message);
      _room?.localParticipant?.publishData(
          Uint8List.fromList(utf8.encode(jsonString)),
          reliable: false,
          topic: "chat");


      // 添加到本地消息列表，使用nickname作为sender
      messages.add(ChatMessage(
        sender: currentUserName.value, // 直接使用当前用户昵称
        content: content,
        role: _getLocalUserRoleString(), // 使用更精确的角色判断
        timestamp: DateTime.now(),
        faceURL: _getFaceURLFromLocalParticipant(),
      ));

      // 清空输入框
      messageController.clear();
    } catch (e) {
      ILogger.e('MeetingLogic', '发送聊天消息失败: $e');
    }
  }

  // 从本地参与者获取头像URL
  String? _getFaceURLFromLocalParticipant() {
    if (localParticipant.value?.metadata == null) return null;

    try {
      Map<String, dynamic> metadataMap;
      if (localParticipant.value!.metadata is String) {
        metadataMap = json.decode(localParticipant.value!.metadata!);
      } else if (localParticipant.value!.metadata is Map) {
        metadataMap =
            Map<String, dynamic>.from(localParticipant.value!.metadata as Map);
      } else {
        return null;
      }

      return metadataMap['faceURL'] as String?;
    } catch (e) {
      ILogger.e('MeetingLogic', '获取本地参与者头像URL失败: $e');
      return null;
    }
  }

  // 切换麦克风状态
  Future<void> toggleMicrophone() async {
    if (_room?.localParticipant == null) return;

    try {
      // 反转当前状态
      final newState = !isMuted.value;

      // 更新麦克风状态
      await _room!.localParticipant!.setMicrophoneEnabled(!newState);

      // 更新状态变量
      isMuted.value = newState;
    } catch (e) {
      ILogger.e('MeetingLogic', '切换麦克风状态失败: $e');
    }
  }

  // 切换摄像头状态
  Future<void> toggleCamera() async {
    if (_room?.localParticipant == null) return;

    try {
      // 反转当前状态
      final newState = !isCameraOff.value;

      // 简单直接的开关摄像头实现
      await _room!.localParticipant!.setCameraEnabled(!newState);

      // 更新状态变量
      isCameraOff.value = newState;

      // 触发UI更新
      update();
    } catch (e) {
      ILogger.e('MeetingLogic', '切换摄像头状态失败: $e');
    }
  }

  // 切换举手状态
  Future<void> toggleRaiseHand() async {
    if (_room?.localParticipant == null) return;

    try {
      // 反转当前状态
      final newState = !hasRaisedHand.value;

      // 准备数据
      Map<String, dynamic> message;
      if (newState) {
        // 举手请求
        message = {
          'type': 'hand_raise',
          'user_id': currentUserId.value,
          'user_name': currentUserName.value,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        final roomName = _room!.name ?? "";
        final result = await apiService.raiseHand(roomName: roomName);

        if (result != null) {
          // 更新状态变量
          hasRaisedHand.value = newState;

          // 显示已举手提示
          Get.snackbar(
            StrRes.meetingStatusHandRaised,
            StrRes.meetingStatusRequestSpeaking,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue.withOpacity(0.7),
            colorText: Colors.white,
            duration: Duration(seconds: 2),
          );

          // 延迟刷新UI，确保状态更新
          Future.delayed(Duration(seconds: 2), () {
            _updateRemoteTracks();
            update();
          });
        }
      } else {
        // 取消举手
        message = {
          'type': 'hand_lower',
          'user_id': currentUserId.value,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        hasRaisedHand.value = newState;
      }

      // 更新元数据 - 通过调用API更新元数据
      // 注意：前端不直接修改元数据，而是通过API请求服务器修改
    } catch (e) {
      ILogger.e('MeetingLogic', '切换举手状态失败: $e');
      // 恢复状态
      hasRaisedHand.value = !hasRaisedHand.value;
    }
  }

  // 切换屏幕共享状态
  Future<void> toggleScreenSharing() async {
    if (_room?.localParticipant == null) return;

    try {
      // 当前状态
      final currentState = isScreenSharing.value;

      if (!currentState) {
        // 开启屏幕共享
        await _room!.localParticipant!.setScreenShareEnabled(true);
        isScreenSharing.value = true;
      } else {
        // 关闭屏幕共享
        await _room!.localParticipant!.setScreenShareEnabled(false);
        isScreenSharing.value = false;
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '切换屏幕共享状态失败: $e');
    }
  }

  // 接受举手请求
  Future<void> acceptRaisedHand(RaisedHandRequest request) async {
    try {
      // 使用core/api_service.dart中的API服务

      // 调用API批准举手请求
      final result = await apiService.approveHandRaise(
        identity: request.user_id, // 用户ID
        roomName: _room?.name ?? '', // 房间名字
      );

      if (result != null) {
        // 移除本地举手请求
        _removeRaisedHandRequest(request.user_id);

        // 添加系统消息
        final message = StrRes.meetingStatusUserApproved.replaceFirst('%s', request.user_name);
        _addSystemMessage(message);

        // 增加计数器值触发UI刷新
        updateCounter.value++;

        // 立即查找并添加该用户到重要角色参与者列表中
        lk.RemoteParticipant? participantToPromote;
        if (_room != null) {
          for (var participant in _room!.remoteParticipants.values) {
            if (participant.identity == request.user_name ||
                participant.identity == request.user_id) {
              participantToPromote = participant;
              break;
            }
          }
        }

        if (participantToPromote != null) {
          // 先检查该参与者是否已在重要角色列表中
          if (!remoteParticipants.contains(participantToPromote)) {
            // 添加到重要角色参与者列表
            remoteParticipants.add(participantToPromote);

            // 记录到手动添加列表，保护期为30秒
            manuallyAddedParticipants[participantToPromote.identity] =
                DateTime.now();
          }

          // 尝试手动更新元数据（如果服务器暂未更新）
          try {
            var metadataMap = <String, dynamic>{
              'role': 'publisher', // 设为连麦者角色
              'hand_raised': false,
              'user_id': participantToPromote.identity,
              'user_name': participantToPromote.identity
            };

            // 将该用户放入重要角色参与者列表，确保UI更新
            if (!remoteParticipants.contains(participantToPromote)) {
              remoteParticipants.add(participantToPromote);

              // 记录到手动添加列表，保护期为30秒
              manuallyAddedParticipants[participantToPromote.identity] =
                  DateTime.now();
            }
          } catch (e) {
            ILogger.e('MeetingLogic', '手动更新元数据失败: $e');
          }

          // 确保UI立即更新
          update();

          // 强制刷新一次轨道
          await Future.delayed(Duration(milliseconds: 300));
          _updateRemoteTracks();
          update();

          // 额外尝试一次全面刷新
          Future.delayed(Duration(seconds: 1), () {
            _forceRefreshRoom();
          });

        } else {
          ILogger.e('MeetingLogic', '无法找到上麦用户: ${request.user_name}');

          // 如果找不到参与者，尝试进行一次强制刷新
          _forceRefreshRoom();

          // 显示提示
          Get.snackbar(
            StrRes.meetingStatusProcessed,
            StrRes.meetingStatsRequestHandled,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue.withOpacity(0.7),
            colorText: Colors.white,
            duration: Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      // 在UI上提示失败 - 保留错误通知，因为这对用户体验很重要
      // Get.snackbar(
      //   StrRes.meetingStatusOperationFailed,
      //   StrRes.meetingStatusDemoteFailed,
      //   snackPosition: SnackPosition.TOP,
      //   backgroundColor: Colors.red.withOpacity(0.7),
      //   colorText: Colors.white,
      //   duration: Duration(seconds: 2),
      // );
    }
  }

  // 拒绝举手请求或将用户下麦
  Future<void> rejectRaisedHand(String identity, String? userName) async {
    try {
      // 尝试查找用户名（如果未提供）
      String displayName = userName ?? '';
      if (displayName.isEmpty) {
        // 在举手列表中查找
        if (displayName.isEmpty) {
          final index =
              raisedHands.indexWhere((req) => req.user_id == identity);
          if (index != -1) {
            displayName = raisedHands[index].user_name;
          }
        }

        // 如果仍然没有找到，使用默认名称
        if (displayName.isEmpty) {
          displayName = userName ?? StrRes.meetingUserThisUser;
        }
      }

      // 调用API将用户下麦
      final result = await apiService.removeFromStage(
          roomName: _room?.name ?? '', identity: identity);

      if (result != null) {
        // 移除本地举手请求
        _removeRaisedHandRequest(identity);

        // 添加系统消息通知
        final message = StrRes.meetingStatusUserRemoved.replaceFirst('%s', displayName);
        _addSystemMessage(message);

        // 增加计数器值触发UI刷新
        updateCounter.value++;

        // 强制刷新一次视图
        Future.delayed(Duration(milliseconds: 300), () {
          _updateRemoteTracks();
          update();
        });
      }
    } catch (e) {
      // 在UI上提示失败 - 保留错误通知
      // Get.snackbar(
      //   StrRes.meetingStatusOperationFailed,
      //   StrRes.meetingStatusRemoveFailed,
      //   snackPosition: SnackPosition.TOP,
      //   backgroundColor: Colors.red.withOpacity(0.7),
      //   colorText: Colors.white,
      //   duration: Duration(seconds: 2),
      // );
    }
  }

// 移出房管
  Future<void> revokeAdmin(String identity, String? userName) async {
    try {
      final result = await apiService.revokeAdmin(
          roomName: _room?.name ?? '', identity: identity);

      if (result != null) {
        // 添加系统消息通知
        final message = StrRes.meetingStatusUserRevokedAdmin.replaceFirst('%s', userName ?? "");
        _addSystemMessage(message);

        // 强制刷新一次视图
        Future.delayed(Duration(milliseconds: 300), () {
          _updateRemoteTracks();
          update();
        });
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '移出房管操作失败: $e');

      // 在UI上提示失败 - 保留错误通知
      // Get.snackbar(
      //   StrRes.meetingStatusOperationFailed,
      //   StrRes.meetingStatusRevokeAdminFailed,
      //   snackPosition: SnackPosition.TOP,
      //   backgroundColor: Colors.red.withOpacity(0.7),
      //   colorText: Colors.white,
      //   duration: Duration(seconds: 2),
      // );
    }
  }

// 设置房管
  Future<void> setAdmin(String identity, String? userName) async {
    try {
      final result = await apiService.setAdmin(
          roomName: _room?.name ?? '', identity: identity);

      if (result != null) {
        // 添加系统消息通知
        final message = StrRes.meetingStatusUserSetAdmin.replaceFirst('%s', userName ?? "");
        _addSystemMessage(message);

        // 强制刷新一次视图
        Future.delayed(Duration(milliseconds: 300), () {
          _updateRemoteTracks();
          update();
        });
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '设置房管操作失败: $e');

      // 在UI上提示失败 - 保留错误通知
      // Get.snackbar(
      //   StrRes.meetingStatusOperationFailed,
      //   StrRes.meetingStatusSetAdminFailed,
      //   snackPosition: SnackPosition.TOP,
      //   backgroundColor: Colors.red.withOpacity(0.7),
      //   colorText: Colors.white,
      //   duration: Duration(seconds: 2),
      // );
    }
  }

  // 结束会议
  void endMeeting() async {
    // 显示确认对话框
    Get.defaultDialog(
      title: StrRes.meetingUiConfirmExit,
      titleStyle: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 提示文本
          Text(
            isHost.value ? StrRes.meetingUiConfirmExitHost : StrRes.meetingUiConfirmExitMember,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          Get.back(); // 关闭确认对话框
          _executeEndMeeting(); // 执行实际的退出逻辑
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          minimumSize: Size(120.w, 45.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          StrRes.meetingUiConfirm,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(120.w, 45.h),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          StrRes.meetingUiCancel,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16.sp,
          ),
        ),
      ),
      radius: 16.r,
      barrierDismissible: true,
    );
  }

  // 实际执行退出会议的逻辑
  void _executeEndMeeting() async {
    // 如果是房主，调用stopStream接口
    if (isHost.value && _room?.name != null) {
      try {
        final result = await apiService.stopStream(roomName: _room!.name!);
        if (result != null) {

          // 获取直播统计数据
          try {
            final statistics = await apiService.livestreamStatisticsSingle(
                roomName: _room!.name!);

            if (statistics != null) {
              // 断开房间连接
              _disconnectRoom();

              // 显示结束页面并传递统计数据
              _showEndScreen(statistics);
              return; // 提前返回，避免执行后面的返回上一页逻辑
            }
          } catch (statsError) {
            ILogger.e('MeetingLogic', '获取直播统计数据失败: $statsError');
          }
        } else {
          ILogger.e('MeetingLogic', '停止直播失败: 返回null');
        }
      } catch (e) {
        ILogger.e('MeetingLogic', '停止直播失败: $e');
      }
    }

    // 断开房间连接
    _disconnectRoom();

    // 返回上一页
    Get.back();
  }

  // 显示结束页面
  void _showEndScreen(Map<String, dynamic> statistics) {
    // 从统计数据中提取关键信息
    final totalUsers = statistics['total_users'] ?? 0;
    final maxOnlineUsers = statistics['max_online_users'] ?? 0;
    final totalRaiseHands = statistics['total_raise_hands'] ?? 0;
    final totalOnStage = statistics['total_on_stage'] ?? 0;

    // 计算直播时长
    DateTime? startTime;
    DateTime now = DateTime.now();
    try {
      if (statistics['start_time'] != null) {
        startTime = DateTime.parse(statistics['start_time']);
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '解析直播创建时间失败: $e');
    }

    // 计算直播时长（秒）- 使用当前时间而不是stop_time
    int durationInSeconds = 0;
    if (startTime != null) {
      durationInSeconds = now.difference(startTime).inSeconds;
      // 防止可能出现的负值情况
      durationInSeconds = durationInSeconds < 0 ? 0 : durationInSeconds;
    } else if (_meetingCreateTime != null) {
      // 如果API返回的创建时间无效，使用本地记录的会议创建时间
      durationInSeconds = now.difference(_meetingCreateTime!).inSeconds;
      durationInSeconds = durationInSeconds < 0 ? 0 : durationInSeconds;
    } else if (_durationInSeconds > 0) {
      // 如果都没有，则使用本地计时器的累计时间
      durationInSeconds = _durationInSeconds;
    }

    // 格式化直播时长
    final hours = (durationInSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes =
        ((durationInSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationInSeconds % 60).toString().padLeft(2, '0');
    final durationFormatted = '$hours:$minutes:$seconds';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          padding: EdgeInsets.all(20.r),
          width: Get.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Text(
                StrRes.meetingUiStreamEnded,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24.h),

              // 统计指标
              _buildStatItem(Icons.timer, StrRes.meetingStatsDuration, durationFormatted),
              _buildStatItem(Icons.visibility, StrRes.meetingStatsViewers, '$totalUsers ${StrRes.meetingStatsPerson}'),
              _buildStatItem(Icons.people, StrRes.meetingStatsMaxOnline, '$maxOnlineUsers ${StrRes.meetingStatsPerson}'),
              _buildStatItem(Icons.front_hand, StrRes.meetingStatsHandCount, '$totalRaiseHands ${StrRes.meetingStatsTimes}'),
              _buildStatItem(Icons.mic, StrRes.meetingStatsStageCount, '$totalOnStage ${StrRes.meetingStatsPerson}'),

              SizedBox(height: 24.h),

              // 确认按钮
              ElevatedButton(
                onPressed: () {
                  // 重置标志位
                  Get.back(); // 关闭对话框
                  Get.back(); // 返回上一页
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 45.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  StrRes.meetingUiConfirmButton,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // 构建单个统计项
  Widget _buildStatItem(IconData icon, String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: Colors.blue, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade700,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.red, size: 28),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // 分享给好友
  void _shareToFriend(String shareText, String meetingLink) {
    Get.back(); // 关闭分享菜单

    // 使用好友选择器

    AppNavigator.startSelectContacts(
      action: SelAction.forward,
    ).then((result) {
      if (result != null && result is Map && result['checkedList'] != null) {
        var checkedList = result['checkedList'];
        for (var item in checkedList) {
          var userID = IMUtils.convertCheckedToUserID(item);
          var groupID = IMUtils.convertCheckedToGroupID(item);

          // 发送分享消息
          _sendShareMessage(
              userID: userID, groupID: groupID, shareText: shareText);
        }
        IMViews.showToast(StrRes.meetingStatusShareSuccess);
      }
    });
  }

  // 发送分享消息
  Future<void> _sendShareMessage(
      {String? userID, String? groupID, required String shareText}) async {
    if (userID == null && groupID == null) {
      return;
    }

    try {
      // 发送文本消息
      final message = await OpenIM.iMManager.messageManager.createTextMessage(
        text: shareText,
      );

      await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: userID,
        groupID: groupID,
        offlinePushInfo: OfflinePushInfo(
          title: StrRes.meetingUiShareMeeting,
          desc: shareText,
        ),
      );
    } catch (e) {
      //ILogger.d('发送分享消息失败: $e');
    }
  }

  // 复制分享文本
  void _copyShareText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    IMViews.showToast(StrRes.meetingStatusCopied);
    Get.back();
  }

  void shareLiveStream() {
    final roomName = _room!.name;
    final shareText = '🎥Live Stream: ${meetingTitle.value}\nRoom ID: $roomName';

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              StrRes.meetingUiShareMeeting,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.person,
                  label: StrRes.meetingUiShareToFriend,
                  onTap: () => _shareToFriend(shareText, roomName ?? ''),
                ),
                _buildShareOption(
                  icon: Icons.content_copy,
                  label: StrRes.meetingUiCopyLink,
                  onTap: () => _copyShareText(shareText),
                ),
              ],
            ),
            SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 8,
              color: Colors.grey.withOpacity(0.1),
            ),
            SizedBox(height: 12),
            InkWell(
              onTap: () => Get.back(),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  StrRes.meetingUiCancel,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  // 控制聊天输入框显示
  void toggleChatInput() {
    isShowingChatInput.value = !isShowingChatInput.value;
  }

  // 隐藏聊天输入框
  void hideChatInput() {
    isShowingChatInput.value = false;
  }

  // 判断当前用户是否是房主或管理员
  bool isHostOrAdmin() {
    // 如果是房主，直接返回true
    if (isHost.value) return true;

    // 检查本地用户元数据中的角色
    if (localParticipant.value != null &&
        localParticipant.value!.metadata != null) {
      try {
        final metadata = localParticipant.value!.metadata;
        ParticipantMetadata? participantMetadata;

        if (metadata is String) {
          Map<String, dynamic> metadataMap = json.decode(metadata);
          participantMetadata = ParticipantMetadata.fromJson(metadataMap);
        } else if (metadata is Map) {
          Map<String, dynamic> metadataMap =
              Map<String, dynamic>.from(metadata as Map);
          participantMetadata = ParticipantMetadata.fromJson(metadataMap);
        }

        if (participantMetadata != null) {
          return participantMetadata.role == UserRole.owner ||
              participantMetadata.role == UserRole.admin;
        }
      } catch (e) {
        ILogger.e('MeetingLogic', '解析本地用户元数据失败: $e');
      }
    }

    return false;
  }

  // 强制用户退出房间
  Future<void> blockViewer(String userId, String userName) async {
    // 显示确认对话框
    Get.defaultDialog(
      title: StrRes.meetingUiConfirmRemoveTitle,
      titleStyle: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 提示文本
          Text(
            StrRes.meetingUiConfirmRemove.replaceFirst('%s', userName),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
      confirm: ElevatedButton(
        onPressed: () {
          Get.back(); // 关闭确认对话框
          _executeBlockViewer(userId, userName); // 执行实际的踢人逻辑
          Get.back();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          minimumSize: Size(120.w, 45.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          StrRes.meetingUiConfirmRemove,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(120.w, 45.h),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          StrRes.meetingUiCancel,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16.sp,
          ),
        ),
      ),
      radius: 16.r,
      barrierDismissible: true,
    );
  }

  // 实际执行踢人的逻辑
  Future<void> _executeBlockViewer(String userId, String userName) async {
    try {

      final result = await apiService.blockViewer(
          identity: userId, // 用户ID
          roomName: _room?.name ?? '' // 房间名字
          );

      if (result != null) {
        // 添加系统消息
        _addSystemMessage('已将 $userName 移出会议');

        // 增加计数器值触发UI刷新
        updateCounter.value++;
      }
    } catch (e) {
      // 在UI上提示失败 - 保留错误通知
      Get.snackbar(
        '操作失败',
        '无法将用户移出会议，请重试',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    }
  }

  Future<void> leaveSpeakerStage(String identity) async {
    if (_room?.localParticipant == null) return;

    try {
      // 调用API下麦
      final result = await apiService.removeFromStage(
          roomName: _room!.name ?? "", identity: identity);

      if (result != null) {
        // 手动更新本地状态
        // 关键优化：先置空再设置，确保Obx能感知到变化
        var originalParticipant = localParticipant.value;
        localParticipant.value = null;

        // 使用微任务确保UI刷新
        Future.microtask(() {
          localParticipant.value = originalParticipant;

          // 强制刷新工具栏
          update();
        });

        Get.snackbar(
          StrRes.meetingStatusDemoted,
          StrRes.meetingStatusEndSpeaking,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.withOpacity(0.7),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '主动下麦失败: $e');
    }
  }

  Future<void> inviteToStage(String identity, String user_name) async {
    try {
      final result = await apiService.inviteToStage(
          roomName: _room!.name ?? "", identity: identity);

      if (result != null) {
        // 手动更新本地状态
        // 增加计数器值触发UI刷新
        updateCounter.value++;

        Get.snackbar(
          StrRes.meetingStatusInvited,
          StrRes.meetingStatusInviteAudience,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.withOpacity(0.7),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '邀请观众上台: $e');
    }
  }

  // 添加acceptInvitation方法
  Future<void> acceptInvitation() async {
    try {
      final result = await apiService.raiseHand(
        roomName: _room?.name ?? '',
      );

      if (result != null) {
        Get.snackbar(
          StrRes.meetingStatusPreparing,
          StrRes.meetingStatusRequestSpeaking,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.blue.withOpacity(0.7),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      // Get.snackbar(
      //   StrRes.meetingStatusOperationFailed,
      //   StrRes.meetingStatusOperationNotSuccessful,
      //   snackPosition: SnackPosition.TOP,
      //   backgroundColor: Colors.red.withOpacity(0.7),
      //   colorText: Colors.white,
      // );
    }
  }

  // 添加rejectInvitation方法
  Future<void> rejectInvitation() async {
    try {
      final result = await apiService.removeFromStage(
        roomName: _room?.name ?? '',
        identity: localParticipant.value?.identity ?? '',
      );

      if (result != null) {
        Get.snackbar(
          StrRes.meetingStatusRejected,
          StrRes.meetingStatusRejectInvite,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.grey.withOpacity(0.7),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '拒绝邀请失败: $e');
    }
  }

  // 根据会议创建时间更新会议时长
  void _updateDurationFromCreateTime() {
    if (_meetingCreateTime == null) return;

    final now = DateTime.now();
    final difference = now.difference(_meetingCreateTime!);

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    meetingDuration.value =
        '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 获取本地用户的角色字符串表示
  String _getLocalUserRoleString() {
    // 首先检查是否为主持人
    if (isHost.value) return StrRes.meetingRoleHost;
    
    // 检查本地参与者元数据中的角色
    final localPart = localParticipant.value;

    if (localPart != null && localPart.metadata != null) {
      try {
        Map<String, dynamic> metadataMap;
        if (localPart.metadata is String) {
          metadataMap = json.decode(localPart.metadata!);
        } else if (localPart.metadata is Map) {
          metadataMap = Map<String, dynamic>.from(localPart.metadata as Map);
        } else {
          return StrRes.meetingRoleAudience;
        }
        // 解析角色字段
        if (metadataMap.containsKey('role')) {
          final roleValue = metadataMap['role']['name'];
          if (roleValue is String) {
            switch (roleValue.toLowerCase()) {
              case 'owner':
                return StrRes.meetingRoleHost;
              case 'admin':
                return StrRes.meetingRoleAdmin;
              case 'publisher':
                return StrRes.meetingRolePublisher;
              default:
                return StrRes.meetingRoleAudience;
            }
          }
        }
      } catch (e) {
        ILogger.e('MeetingLogic', '解析本地用户角色失败: $e');
      }
    }
    
    // 默认为观众
    return StrRes.meetingRoleAudience;
  }

  // 切换前置/后置摄像头
  Future<void> switchCamera() async {
    if (localParticipant.value == null) return;

    try {
      // 检查摄像头是否关闭
      if (isCameraOff.value) {
        ILogger.d('MeetingLogic', '摄像头已关闭，无法切换');
        return;
      }

      // 查找摄像头视频轨道
      final videoPublications = localParticipant.value!.videoTrackPublications
          .where((pub) => pub.source == lk.TrackSource.camera && pub.track != null);
      
      if (videoPublications.isNotEmpty) {
        final localTrack = videoPublications.first.track as lk.LocalVideoTrack;
        
        // 切换摄像头位置
        final newPosition = isFrontCamera.value 
            ? lk.CameraPosition.back 
            : lk.CameraPosition.front;
        
        // 使用LiveKit提供的方法切换摄像头
        await localTrack.setCameraPosition(newPosition);
        
        // 更新摄像头方向状态
        isFrontCamera.value = !isFrontCamera.value;
        
        ILogger.d('MeetingLogic', '已切换到${isFrontCamera.value ? "前置" : "后置"}摄像头');
      } else {
        throw Exception('未找到有效的摄像头轨道');
      }
    } catch (e) {
      ILogger.e('MeetingLogic', '切换摄像头失败: $e');
     
    }
  }
}
