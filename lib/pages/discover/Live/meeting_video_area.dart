import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'meeting_logic.dart';
import 'dart:math';
import 'dart:convert';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';

class MeetingVideoArea extends StatelessWidget {
  final MeetingLogic logic;

  const MeetingVideoArea({
    Key? key,
    required this.logic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 使用GetBuilder包装整个组件，确保在逻辑更新时能够重新构建
    return GetBuilder<MeetingLogic>(
      init: logic,
      builder: (controller) {
        // 移除动态UniqueKey，避免不必要的完全重建
        // final globalKey = UniqueKey(); // 删除这行
        
        return RepaintBoundary(
          // 使用固定的key代替动态key
          key: const ValueKey('meeting_video_area_root'),
          child: Stack(
            children: [
              Obx(() => controller.screenShareTrack.value != null
                ? _buildLayoutWithScreenShare()
                : _buildNormalLayout()
              ),
            ],
          ),
        );
      },
    );
  }

  // 标准布局 - 九宫格视频
  Widget _buildNormalLayout() {
    // 无论用户角色如何，都显示完整的视频网格
    return _buildVideoGrid();
  }

  // 判断当前用户是否为普通观众（非主持人、非管理员、非连麦者）
  bool _isCurrentUserRegularViewer() {
    // 如果是主持人，不是普通观众
    if (logic.isHost.value) return false;
    
    // 检查本地参与者元数据中的角色
    final localParticipant = logic.localParticipant.value;
    if (localParticipant != null && localParticipant.metadata != null) {
      try {
        ParticipantMetadata? metadata;
        if (localParticipant.metadata is String) {
          Map<String, dynamic> metadataMap = json.decode(localParticipant.metadata!);
          metadata = ParticipantMetadata.fromJson(metadataMap);
        } else if (localParticipant.metadata is Map) {
          Map<String, dynamic> metadataMap = Map<String, dynamic>.from(localParticipant.metadata as Map);
          metadata = ParticipantMetadata.fromJson(metadataMap);
        }
        
        if (metadata != null) {
          // 如果不是普通用户角色，则不是普通观众
          return metadata.role == UserRole.user;
        }
      } catch (e) {
        // 解析错误，默认为普通观众
        return true;
      }
    }
    
    // 默认为普通观众
    return true;
  }
  
  // 仅显示当前用户自己的视频
  Widget _buildSingleLocalUserView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.05),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频容器占满整个区域
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 本地视频
                _buildLocalVideoView(),
                
                // 底部信息栏
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 麦克风图标
                        Obx(() => Icon(
                          logic.isMuted.value ? Icons.mic_off : Icons.mic,
                          color: logic.isMuted.value ? Colors.red : Colors.green,
                          size: 16.sp,
                        )),
                        SizedBox(width: 8.w),
                        // 用户名
                        Text(
                          '${logic.currentUserName.value} (${StrRes.meetingMe})',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 添加提示文本到顶部
          Positioned(
            left: 0,
            right: 0,
            top: 10.h,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 10.w),
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  StrRes.meetingViewerOnly,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 屏幕共享布局 - 顶部视频列表+底部屏幕共享
  Widget _buildLayoutWithScreenShare() {
    // 简化响应式包装，只使用一个Obx
    return Obx(() {
      // 只监听关键状态变化
      final _ = logic.updateCounter.value;
      
      return Column(
        // 使用固定Key，避免每次重建
        key: ValueKey("screen_share_layout"),
        children: [
          // 顶部视频列表占视频区的1/3高度
          Flexible(
            flex: 1,
            child: _buildHorizontalVideoList(),
          ),
          
          // 底部屏幕共享区域占视频区的2/3高度
          Flexible(
            flex: 2,
            child: _buildScreenShareView(),
          ),
        ],
      );
    });
  }

  // 顶部水平滚动视频列表
  Widget _buildHorizontalVideoList() {
    // 简化响应式包装
    return Obx(() {
      // 只监听关键状态变化
      final _ = logic.updateCounter.value;
      final participants = logic.remoteParticipants;
      final localPart = logic.localParticipant.value;
      
      // 创建视频组件列表
      final videoCards = <Widget>[];
      
      // 创建一个Set存储已经添加的参与者ID，防止同一参与者在列表中出现多次
      final processedParticipantIds = <String>{};
      
      // 判断当前用户是否为普通观众
      bool isRegularViewer = _isCurrentUserRegularViewer();
      
      // 如果不是普通观众，才添加本地视频
      if (!isRegularViewer && localPart != null) {
        final localId = localPart.identity;
        // 确保本地参与者ID还未处理过
        if (!processedParticipantIds.contains(localId)) {
          processedParticipantIds.add(localId);
          videoCards.add(_buildParticipantCardForList(
            isLocal: true, 
            participant: null,
            trackPub: null,
          ));
        }
      }
      
      // 使用remoteTracks而不是remoteParticipants作为数据源
      final screenShareIdentity = logic.screenShareParticipant.value?.identity;
      
      // 添加所有远程视频轨道
      for (final trackPub in logic.remoteTracks) {
        // 跳过屏幕共享轨道
        if (trackPub.source == lk.TrackSource.screenShareVideo) continue;
        
        if (trackPub is lk.RemoteTrackPublication) {
          // 不再跳过屏幕共享者的摄像头视频，现在同时显示共享屏幕和摄像头视频
          final participantId = trackPub.participant.identity;
          // 检查该参与者是否已经添加过视频轨道
          if (!processedParticipantIds.contains(participantId)) {
            processedParticipantIds.add(participantId);
            videoCards.add(_buildParticipantCardForList(
              isLocal: false,
              participant: trackPub.participant,
              trackPub: trackPub,
            ));
          }
        }
      }
      
      // 添加没有视频轨道的重要角色参与者
      for (final participant in logic.importantParticipantsWithoutTracks) {
        // 现在不再跳过屏幕共享者
        // 确保该参与者尚未被添加到列表中
        if (!processedParticipantIds.contains(participant.identity)) {
          processedParticipantIds.add(participant.identity);
          videoCards.add(_buildParticipantCardForList(
            isLocal: false,
            participant: participant,
            trackPub: null,
          ));
        }
      }
      
      // 如果没有视频，显示提示信息
      if (videoCards.isEmpty) {
        return Container(
          alignment: Alignment.center,
          child: Text(
            StrRes.meetingNoParticipants,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp),
          ),
        );
      }
      
      // 计算每个视频卡的宽度 - 设置为视频区宽度的1/3
      double cardWidth = Get.width / 3;
      
      return Container(
        // 使用稳定的Key，避免不必要的重建
        key: ValueKey("horizontal_video_list"),
        color: Colors.black.withOpacity(0.05),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          children: videoCards.map((card) => 
            Container(
              width: cardWidth,
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              child: card,
            )
          ).toList(),
        ),
      );
    });
  }
  
  // 为水平列表构建的小型视频卡片
  Widget _buildParticipantCardForList({
    required bool isLocal,
    required lk.RemoteParticipant? participant,
    required lk.TrackPublication? trackPub,
  }) {
    // 简化响应式包装
    return Obx(() {
      // 监听必要的状态变化
      final updateCount = logic.updateCounter.value;
      
      final userName = isLocal 
        ? '${logic.currentUserName.value} (${StrRes.meetingMe})'
        : _getUserNickname(participant!);
      
      final isMuted = isLocal 
        ? logic.isMuted.value
        : !participant!.audioTrackPublications.any((pub) => !pub.muted && pub.subscribed);
      
      final role = isLocal && logic.isHost.value 
        ? StrRes.meetingRoleHost
        : _getRoleForParticipant(participant);

      // 检查是否正在说话
      final identity = isLocal ? logic.localParticipant.value?.identity : participant?.identity;
      final isSpeaking = identity != null && logic.speakingParticipants.containsKey(identity);
      final speakingLevel = identity != null ? (logic.speakingParticipants[identity] ?? 0.0) : 0.0;
      
      // 检查是否是屏幕共享者
      final isScreenSharer = !isLocal && 
          logic.screenShareParticipant.value?.identity == participant?.identity;
      
      // 使用更稳定的key，包含更新计数器以确保状态变化时更新
      final cardKey = isLocal 
        ? "local_list_${updateCount}"
        : "${participant?.identity}_${trackPub?.sid ?? 'notrack'}_${updateCount}";
      
      // 检查视频轨道是否真正活跃
      bool hasActiveVideo = false;
      lk.VideoTrack? activeVideoTrack;
      
      if (!isLocal && trackPub != null) {
        // 确保轨道已订阅、未静音且轨道对象存在
        if (trackPub.subscribed && !trackPub.muted && trackPub.track != null) {
          try {
            activeVideoTrack = trackPub.track as lk.VideoTrack;
            hasActiveVideo = true;
          } catch (e) {
            ILogger.e("水平列表视频轨道状态检查失败: $e");
            hasActiveVideo = false;
          }
        }
      } else if (isLocal) {
        // 本地视频逻辑
        hasActiveVideo = !logic.isCameraOff.value;
      }
      
      // 调试日志
      if (!isLocal) {
        ILogger.d("水平列表 - 用户 $userName 视频状态: hasActiveVideo=$hasActiveVideo");
      }
      
      return Stack(
        children: [
          // 视频内容容器 - 稳定不闪烁
          Container(
            key: ValueKey(cardKey),
            margin: EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              // 为屏幕共享者添加蓝色边框
              border: isScreenSharer ? Border.all(
                color: Colors.blue.shade300,
                width: 2.0,
              ) : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 视频内容或占位头像
                isLocal 
                  ? (hasActiveVideo ? _buildLocalVideoView() : _buildAvatarPlaceholder(userName, forceKey: "local_${updateCount}", participant: logic.localParticipant.value))
                  : (hasActiveVideo && activeVideoTrack != null)
                    ? RepaintBoundary(
                        child: lk.VideoTrackRenderer(
                          activeVideoTrack,
                          fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                          // 使用带有更新计数器的key以确保刷新
                          key: ValueKey("list_video_${trackPub!.sid}_${updateCount}"),
                        ),
                      )
                    : _buildAvatarPlaceholder(userName, forceKey: "avatar_${participant?.identity}", participant: participant),
              
                // 底部信息
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 麦克风图标
                        Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          color: isMuted ? Colors.red : Colors.green,
                          size: 12.sp,
                        ),
                        // 用户名 (简短显示)
                        Text(
                          userName.split(' ')[0],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        // 角色标签
                        if (role.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 1.h),
                            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: _getRoleColor(role).withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                        // 如果是屏幕共享者，添加屏幕共享标记
                        if (isScreenSharer)
                          Container(
                            margin: EdgeInsets.only(top: 1.h),
                            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                            child: Text(
                              StrRes.meetingScreenSharing,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // 如果远程用户没有视频，显示摄像头关闭图标
                if (!isLocal && !hasActiveVideo)
                  Positioned(
                    top: 2.h,
                    left: 2.w,
                    child: Container(
                      padding: EdgeInsets.all(2.r),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                      child: Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                        size: 8.sp,
                      ),
                    ),
                  ),
                
                // 如果是远程用户并正在举手，显示举手图标
                if (!isLocal && participant != null && _isParticipantRaisingHand(participant))
                  Positioned(
                    top: 2.h,
                    right: 2.w,
                    child: Container(
                      padding: EdgeInsets.all(2.r),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pan_tool,
                        color: Colors.white,
                        size: 8.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 边框层 - 单独的动画层
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            margin: EdgeInsets.all(1),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSpeaking 
                    ? Color.lerp(Colors.green, Colors.green.shade700, speakingLevel) ?? Colors.green
                    : Colors.transparent,
                width: isSpeaking ? 2.0 : 0.0,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ],
      );
    });
  }

  // 视频网格 - 标准九宫格布局
  Widget _buildVideoGrid() {
    // 使用固定的key，避免不必要的重建
    const gridKey = "video_grid";
    
    return Obx(() {
      // 监听必要的状态变量
      final _ = logic.updateCounter.value;
      
      // 创建视频组件列表
      final tracks = <Widget>[];
      
      // 创建一个Set存储已经添加的参与者ID，防止同一参与者在网格中出现多次
      final processedParticipantIds = <String>{};
      
      // 判断当前用户是否为普通观众
      bool isRegularViewer = _isCurrentUserRegularViewer();
      
      // 如果不是普通观众，才添加本地视频
      if (!isRegularViewer && logic.localParticipant.value != null) {
        final localId = logic.localParticipant.value!.identity;
        // 确保本地参与者ID还未处理过
        if (!processedParticipantIds.contains(localId)) {
          processedParticipantIds.add(localId);
          tracks.add(_buildLocalParticipantTile());
        }
      }
      
      // 添加远程视频
      for (final trackPub in logic.remoteTracks) {
        // 跳过屏幕共享轨道
        if (trackPub.source == lk.TrackSource.screenShareVideo) continue;
        
        if (trackPub is lk.RemoteTrackPublication) {
          final participantId = trackPub.participant.identity;
          // 检查该参与者是否已经添加过视频轨道
          if (!processedParticipantIds.contains(participantId)) {
            processedParticipantIds.add(participantId);
            tracks.add(_buildRemoteParticipantTile(trackPub.participant, trackPub));
          }
        }
      }
      
      // 添加没有视频轨道的重要角色参与者
      for (final participant in logic.importantParticipantsWithoutTracks) {
        // 确保该参与者尚未被添加到网格中
        if (!processedParticipantIds.contains(participant.identity)) {
          processedParticipantIds.add(participant.identity);
          tracks.add(_buildParticipantPlaceholder(participant));
        }
      }
      
      // 如果没有视频，显示提示信息
      if (tracks.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 40.sp,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 8.h),
              Text(
                StrRes.meetingNoParticipants,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
              ),
            ],
          ),
        );
      }
      
      // 根据视频数量确定布局
      int crossAxisCount; // 列数
      
      if (tracks.length == 1) {
        crossAxisCount = 1; // 单个视频
      } else if (tracks.length <= 4) {
        crossAxisCount = 2; // 2-4个视频
      } else {
        crossAxisCount = 3; // 5-9个视频
      }
      
      // 使用RepaintBoundary包装整个网格，提高渲染性能
      return RepaintBoundary(
        key: const ValueKey(gridKey),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: GridView.builder(
            key: const ValueKey("grid_builder"),
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero, // 移除内边距
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.0, // 正方形网格
              crossAxisSpacing: 1, // 最小间距
              mainAxisSpacing: 1, // 最小间距
            ),
            itemCount: tracks.length > 9 ? 9 : tracks.length,
            itemBuilder: (context, index) {
              return tracks[index];
            },
          ),
        ),
      );
    });
  }

  // 本地参与者视频卡片
  Widget _buildLocalParticipantTile() {
    // 使用固定key，避免不必要的重建
    const localTileKey = "local_tile";
    
    return Obx(() {
      // 监听状态变化
      final updateCount = logic.updateCounter.value;
      
      // 检查本地用户是否正在说话
      final localId = logic.localParticipant.value?.identity;
      final isSpeaking = localId != null && logic.speakingParticipants.containsKey(localId);
      final speakingLevel = localId != null ? (logic.speakingParticipants[localId] ?? 0.0) : 0.0;
      
      return Stack(
        children: [
          // 视频容器 - 保持稳定不闪烁
          Container(
            key: const ValueKey(localTileKey),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 视频画面
                _buildLocalVideoView(),
                
                // 底部名称和角色标签
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 麦克风图标和名称在一行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 麦克风图标
                            Obx(() => Icon(
                              logic.isMuted.value ? Icons.mic_off : Icons.mic,
                              color: logic.isMuted.value ? Colors.red : Colors.green,
                              size: 14.sp,
                            )),
                            SizedBox(width: 4.w),
                            // 用户名
                            Expanded(
                              child: Text(
                                '${logic.currentUserName.value} (${StrRes.meetingMe})',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        // 如果是主持人，显示角色标签
                        Obx(() => logic.isHost.value ? Container(
                          margin: EdgeInsets.only(top: 1.h),
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            StrRes.meetingRoleHost,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ) : SizedBox()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 单独的边框层
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              border: Border.all(
                // 根据说话状态设置边框颜色
                color: isSpeaking 
                    ? Color.lerp(Colors.green, Colors.green.shade700, speakingLevel) ?? Colors.green
                    : Colors.grey.shade300,
                // 说话时边框更宽
                width: isSpeaking ? 2.0 * (0.5 + speakingLevel) : 1.0,
              ),
            ),
            child: const SizedBox.expand(), // 透明的全尺寸容器
          ),
        ],
      );
    });
  }
  
  // 远程参与者视频卡片
  Widget _buildRemoteParticipantTile(
      lk.RemoteParticipant participant, lk.TrackPublication? trackPub) {
    // 使用参与者身份和轨道ID作为key
    final tileKey = "${participant.identity}_${trackPub?.sid ?? 'notrack'}";
    return Obx(() {
      // 监听状态变化
      final updateCount = logic.updateCounter.value;
      
      // 检查参与者是否正在说话
      final isSpeaking = logic.speakingParticipants.containsKey(participant.identity);
      final speakingLevel = logic.speakingParticipants[participant.identity] ?? 0.0;
      
      // 检查视频轨道是否真正活跃
      bool hasActiveVideo = false;
      lk.VideoTrack? activeVideoTrack;
      
      if (trackPub != null) {
        // 确保轨道已订阅、未静音且轨道对象存在
        if (trackPub.subscribed && !trackPub.muted && trackPub.track != null) {
          try {
            activeVideoTrack = trackPub.track as lk.VideoTrack;
            hasActiveVideo = true;
          } catch (e) {
            ILogger.e("远程参与者视频轨道状态检查失败: $e");
            hasActiveVideo = false;
          }
        }
      }
      
      // 检查音频状态
      final isMuted = !participant.audioTrackPublications.any((pub) => !pub.muted && pub.subscribed);
      
      // 用户名称
      final userName = _getUserNickname(participant);
      
      // 用户角色
      final role = _getRoleForParticipant(participant);
      
      // 检查是否是屏幕共享者
      final isScreenSharer = logic.screenShareParticipant.value?.identity == participant.identity;
      
      return Stack(
        children: [
          // 视频容器 - 保持稳定不闪烁
          Container(
            key: ValueKey("video_${tileKey}"),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              // 如果是屏幕共享者，添加特殊的边框标记
              border: isScreenSharer ? Border.all(
                color: Colors.blue.shade300,
                width: 2.0,
              ) : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 视频画面或占位头像
                hasActiveVideo && activeVideoTrack != null
                    ? RepaintBoundary(
                        child: lk.VideoTrackRenderer(
                          activeVideoTrack,
                          fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                          key: ValueKey("video_${trackPub!.sid}"),
                        ),
                      )
                    : _buildAvatarPlaceholder(userName, forceKey: "avatar_${participant.identity}", participant: participant),
                
                // 底部名称和角色标签
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 麦克风图标和名称在一行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 麦克风图标
                            Icon(
                              isMuted ? Icons.mic_off : Icons.mic,
                              color: isMuted ? Colors.red : Colors.green,
                              size: 14.sp,
                            ),
                            SizedBox(width: 4.w),
                            // 用户名
                            Expanded(
                              child: Text(
                                userName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        // 如果有角色，显示角色标签
                        if (role.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 1.h),
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: _getRoleColor(role),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          
                        // 如果是屏幕共享者，添加屏幕共享标记
                        if (isScreenSharer)
                          Container(
                            margin: EdgeInsets.only(top: 1.h),
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              StrRes.meetingScreenSharing,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // 如果视频关闭，在左上角显示摄像头关闭图标
                if (!hasActiveVideo)
                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                    ),
                  ),
                
                // 如果参与者正在举手，显示举手图标
                if (_isParticipantRaisingHand(participant))
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pan_tool,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 说话边框效果 - 分离动画，避免重建内部组件
          AnimatedContainer(
            key: ValueKey("border_${tileKey}"),
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSpeaking ? Colors.yellow : Colors.transparent,
                width: isSpeaking ? 3.0 : 0.0,
              ),
            ),
          ),
          
          // 举手图标
          if (participant.metadata != null && _tryParseMetadata(participant.metadata)?.hand_raised == true)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pan_tool,
                  color: Colors.yellow,
                  size: 16,
                ),
              ),
            ),
        ],
      );
    });
  }

  // 屏幕共享视图
  Widget _buildScreenShareView() {
    return Obx(() {
      // 确保有屏幕共享轨道
      if (logic.screenShareTrack.value == null) {
        return Center(
          child: Text(StrRes.meetingScreenShareEnded, style: TextStyle(color: Colors.grey.shade700)),
        );
      }
      
      final screenShareTrack = logic.screenShareTrack.value!;
      final participant = logic.screenShareParticipant.value;
      final userName = participant != null ? _getUserNickname(participant) : "用户";
      final role = participant != null ? _getRoleForParticipant(participant) : "";
      
      // 使用稳定的Key，避免每次都重建
      final screenShareKey = "screen_share_view";
      
      return Container(
        key: ValueKey(screenShareKey),
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 屏幕共享内容
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: screenShareTrack.track != null 
                ? RepaintBoundary(
                    child: lk.VideoTrackRenderer(
                      screenShareTrack.track as lk.VideoTrack,
                      fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      // 使用固定Key，避免每次都重建
                      key: ValueKey("screen_track_${screenShareTrack.sid}"),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.desktop_mac, size: 40.sp, color: Colors.grey.shade400),
                        SizedBox(height: 8.h),
                        Text(
                          StrRes.meetingScreenShareLoading,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                        ),
                      ],
                    ),
                  ),
            ),
            
            // 右上角全屏按钮
            Positioned(
              top: 8.h,
              right: 8.w,
              child: InkWell(
                onTap: () {
                  _showFullScreenShare(screenShareTrack);
                },
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ),
            ),
            
            // 底部信息条
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.desktop_mac, color: Colors.white, size: 16.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$userName ${StrRes.meetingScreenSharing}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (role.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(left: 8.w),
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: _getRoleColor(role),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // 显示全屏共享
  void _showFullScreenShare(lk.TrackPublication screenShareTrack) {
    // 使用固定Key，避免不必要的重建
    final fullscreenKey = "fullscreen_share";
    
    Get.dialog(
      Dialog.fullscreen(
        child: Stack(
          key: ValueKey(fullscreenKey),
          fit: StackFit.expand,
          children: [
            // 屏幕共享内容
            Container(
              color: Colors.black,
              child: screenShareTrack.track != null 
                ? RepaintBoundary(
                    child: lk.VideoTrackRenderer(
                      screenShareTrack.track as lk.VideoTrack,
                      fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      // 使用固定Key，避免不必要的重建
                      key: ValueKey("fullscreen_track_${screenShareTrack.sid}"),
                    ),
                  )
                : Center(
                    child: Text(
                      StrRes.meetingScreenShareLoading,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
            ),
            
            // 顶部控制栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(Get.context!).padding.top),
                color: Colors.black45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                    // 标题
                    Text(
                      '${logic.screenShareParticipant.value != null ? _getUserNickname(logic.screenShareParticipant.value!) : "用户"}${StrRes.meetingScreenOf}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // 退出全屏
                    IconButton(
                      icon: Icon(Icons.fullscreen_exit, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false, // 防止点击外部关闭
    );
  }

  // 本地视频渲染
  Widget _buildLocalVideoView() {
    // 使用固定的key
    final localVideoKey = "local_video";
    
    return Obx(() {
      final isCameraOff = logic.isCameraOff.value;
      final userName = logic.currentUserName.value;
      
      if (isCameraOff) {
        return _buildAvatarPlaceholder(userName, forceKey: "local_avatar", participant: logic.localParticipant.value);
      } else if (logic.localParticipant.value != null) {
        // 查找本地视频轨道
        lk.LocalTrackPublication? cameraTrackPub;
        for (var pub in logic.localParticipant.value!.videoTrackPublications) {
          if (pub.source != lk.TrackSource.screenShareVideo && 
              pub.track != null) {
            cameraTrackPub = pub;
            break;
          }
        }
        
        if (cameraTrackPub?.track != null) {
          return RepaintBoundary(
            child: lk.VideoTrackRenderer(
              cameraTrackPub!.track as lk.VideoTrack,
              fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              key: ValueKey(localVideoKey),
            ),
          );
        }
      }
      
      return _buildAvatarPlaceholder(userName, forceKey: "local_fallback", participant: logic.localParticipant.value);
    });
  }

  // 为占位头像创建一个统一的方法，确保所有地方风格一致
  Widget _buildAvatarPlaceholder(String userName, {String? forceKey, lk.Participant? participant}) {
    final uniqueKey = forceKey ?? UniqueKey().toString();
    
    // 尝试获取头像URL
    String? faceURL;
    if (participant != null) {
      try {
        if (participant.metadata != null) {
          var metadataMap = _parseMetadataMap(participant.metadata);
          if (metadataMap != null) {
            faceURL = metadataMap['faceURL'] as String?;
          }
        }
      } catch (e) {
        ILogger.e('MeetingVideoArea', '获取头像URL失败: $e');
      }
    }
    
    return Container(
      key: ValueKey("avatar_${uniqueKey}"),
      color: Colors.grey.shade100, // 统一的背景色
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 如果有头像URL，显示网络图片，否则显示文字头像
            faceURL != null && faceURL.isNotEmpty
              ? CircleAvatar(
                  radius: 40.r,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: NetworkImage(faceURL),
                  onBackgroundImageError: (e, stackTrace) {
                    ILogger.e('MeetingVideoArea', '加载头像图片失败: $e');
                  },
                )
              : CircleAvatar(
                  radius: 40.r,
                  backgroundColor: _getAvatarColor(userName),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            SizedBox(height: 8.h),
            Text(
              StrRes.meetingCameraOff,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
  
  // 辅助方法：解析元数据Map
  Map<String, dynamic>? _parseMetadataMap(dynamic metadata) {
    try {
      if (metadata is String) {
        return json.decode(metadata);
      } else if (metadata is Map) {
        return Map<String, dynamic>.from(metadata as Map);
      }
    } catch (e) {
      ILogger.e('MeetingVideoArea', '解析元数据失败: $e');
    }
    return null;
  }

  // 检查参与者是否正在举手
  bool _isParticipantRaisingHand(lk.RemoteParticipant participant) {
    for (var request in logic.raisedHands) {
      if (request.user_id == participant.identity || request.user_name == participant.identity) {
        return true;
      }
    }
    
    // 也从元数据中检查举手状态
    try {
      if (participant.metadata != null) {
        final metadata = participant.metadata;
        Map<String, dynamic> metadataMap;
        
        if (metadata is String) {
          metadataMap = json.decode(metadata);
        } else if (metadata is Map) {
          metadataMap = Map<String, dynamic>.from(metadata as Map<dynamic, dynamic>);
        } else {
          return false;
        }
        
        if (metadataMap.containsKey('hand_raised')) {
          return metadataMap['hand_raised'] == true;
        }
      }
    } catch (e) {
      //logger.e('无法解析参与者元数据: $e');
    }
    
    return false;
  }

  // 获取参与者角色 - 从LiveKit元数据中获取角色
  String _getRoleForParticipant(lk.RemoteParticipant? participant) {
    if (participant == null) return '';
    
    // 检查当前用户是否是房主
    bool isLocalUserOwner = logic.isHost.value;
    
    try {
      if (participant.metadata != null) {
        final metadata = participant.metadata;
        Map<String, dynamic> metadataMap;
        
        if (metadata is String) {
          metadataMap = json.decode(metadata);
        } else if (metadata is Map) {
          metadataMap = Map<String, dynamic>.from(metadata as Map<dynamic, dynamic>);
        } else {
          return '';
        }
        
        // 解析角色字段
        if (metadataMap.containsKey('role')) {
          final roleValue = metadataMap['role'];
          UserRole role = UserRole.user;
          
          if (roleValue is String) {
            switch (roleValue.toLowerCase()) {
              case 'owner':
                role = UserRole.owner;
                break;
              case 'admin':
                role = UserRole.admin;
                break;
              case 'publisher':
                role = UserRole.publisher;
                break;
              default:
                role = UserRole.user;
            }
          }
          
          // 如果本地用户是房主，但远程用户也显示为房主，则将远程用户降级为管理员
          if (role == UserRole.owner && isLocalUserOwner) {
            // 记录可能的角色冲突
            ILogger.d('MeetingVideoArea', '检测到角色冲突：本地用户和远程用户 ${participant.identity} 都是房主。将远程用户作为管理员显示。');
            role = UserRole.admin; // 降级为管理员显示
          }
          
          // 返回对应的中文角色名称
          switch (role) {
            case UserRole.owner:
              return StrRes.meetingRoleHost;
            case UserRole.admin:
              return StrRes.meetingRoleAdmin;
            case UserRole.publisher:
              return StrRes.meetingRolePublisher;
            case UserRole.user:
            default:
              return '';
          }
        }
      }
    } catch (e) {
      //logger.e('无法获取参与者角色: $e');
    }
    
  
    return '';
  }

  // 获取角色对应的颜色
  Color _getRoleColor(String role) {
    switch (role) {
      case '主持人':
        return Colors.red;
      case '管理员':
        return Colors.orange;
      case '参与者':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // 获取头像颜色
  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    
    final index = name.hashCode % colors.length;
    return colors[index];
  }

  // 为没有视频轨道的重要角色参与者创建占位符
  Widget _buildParticipantPlaceholder(lk.RemoteParticipant participant) {
    // 检查该参与者是否静音
    bool isMuted = true;
    for (var pub in participant.audioTrackPublications) {
      if (!pub.muted && pub.subscribed) {
        isMuted = false;
        break;
      }
    }
    
    // 确定角色标签 - 从元数据中获取
    String role = _getRoleForParticipant(participant);
    String userName = _getUserNickname(participant);
    
    // 使用固定格式的key
    final placeholderKey = "placeholder_${participant.identity}";
    
    return Container(
      key: ValueKey(placeholderKey),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 显示占位头像
          _buildAvatarPlaceholder(userName, forceKey: "placeholder_avatar_${participant.identity}", participant: participant),
          
          // 底部名称和角色标签
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 麦克风图标和名称在一行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 麦克风图标
                      Icon(
                        isMuted ? Icons.mic_off : Icons.mic,
                        color: isMuted ? Colors.red : Colors.green,
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      // 用户名
                      Expanded(
                        child: Text(
                          userName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  // 角色标签
                  if (role.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 1.h),
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: _getRoleColor(role),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 新增辅助方法获取用户昵称
  String _getUserNickname(lk.Participant participant) {
    try {
      if (participant.metadata != null) {
        Map<String, dynamic> metadataMap;
        if (participant.metadata is String) {
          metadataMap = json.decode(participant.metadata as String);
          return metadataMap['nickname'] ?? participant.identity;
        } else if (participant.metadata is Map) {
          metadataMap = Map<String, dynamic>.from(participant.metadata as Map);
          return metadataMap['nickname'] ?? participant.identity;
        }
      }
    } catch (e) {
      ILogger.e('MeetingVideoArea', '解析元数据失败: $e');
    }
    // 如果没有nickname或解析失败，则使用identity作为回退
    return participant.identity;
  }

  // 尝试解析参与者元数据
  ParticipantMetadata? _tryParseMetadata(String? metadataStr) {
    if (metadataStr == null) return null;
    try {
      Map<String, dynamic> metadataMap = json.decode(metadataStr);
      return ParticipantMetadata.fromJson(metadataMap);
    } catch (e) {
      return null;
    }
  }
} 