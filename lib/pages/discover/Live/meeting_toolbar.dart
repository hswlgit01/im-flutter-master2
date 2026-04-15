import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';
import 'meeting_logic.dart';
import 'dart:convert';
import 'package:livekit_client/livekit_client.dart' as lk; // 添加livekit导入

class MeetingToolbar extends StatelessWidget {
  final MeetingLogic logic;

  MeetingToolbar({
    Key? key,
    required this.logic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildBottomBar(context);
  }

  // 底部工具栏
  Widget _buildBottomBar(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 工具栏主区域
        Container(
          height: 66.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Obx(() {
            // 获取按钮列表
            final List<Widget> buttons = [];

            // 检查当前用户是否为普通观众
            bool isRegularViewer = _isCurrentUserRegularViewer();

            // 麦克风按钮 - 所有人都有
            buttons.add(_buildCircularButton(
              icon: Icon(
                logic.isMuted.value ? Icons.mic_off : Icons.mic,
                color: Colors.grey.shade800,
                size: 22,
              ),
              size: 44.w,
              onPressed:
                  isRegularViewer ? null : () => logic.toggleMicrophone(),
              backgroundColor: Colors.grey.shade100,
              gradientColors: isRegularViewer
                  ? [Colors.grey.shade200, Colors.grey.shade300] // 禁用状态
                  : !logic.isMuted.value
                      ? [Colors.blue.shade50, Colors.blue.shade100]
                      : [Colors.grey.shade50, Colors.grey.shade200],
            ));

            // 摄像头按钮 - 所有人都有
            buttons.add(_buildCircularButton(
              icon: Icon(
                logic.isCameraOff.value ? Icons.videocam_off : Icons.videocam,
                color: Colors.grey.shade800,
                size: 22,
              ),
              size: 44.w,
              onPressed: isRegularViewer ? null : () => logic.toggleCamera(),
              backgroundColor: Colors.grey.shade100,
              gradientColors: isRegularViewer
                  ? [Colors.grey.shade200, Colors.grey.shade300] // 禁用状态
                  : !logic.isCameraOff.value
                      ? [Colors.blue.shade50, Colors.blue.shade100]
                      : [Colors.grey.shade50, Colors.grey.shade200],
            ));

            // 切换摄像头按钮 - 仅当摄像头开启时可用
            buttons.add(_buildCircularButton(
              icon: Icon(
                Icons.flip_camera_ios,
                color: Colors.grey.shade800,
                size: 22,
              ),
              size: 44.w,
              onPressed: (isRegularViewer || logic.isCameraOff.value) 
                  ? null 
                  : () => logic.switchCamera(),
              backgroundColor: Colors.grey.shade100,
              gradientColors: (isRegularViewer || logic.isCameraOff.value)
                  ? [Colors.grey.shade200, Colors.grey.shade300] // 禁用状态
                  : [Colors.blue.shade50, Colors.blue.shade100],
            ));

            // 连线/举手按钮 - 只有非房主才显示
            if (!logic.isHost.value) {
              // 判断是否已经是连麦者（Publisher）或管理员（Admin）
              buttons.add(Obx(() {
                // 先定义默认角色为普通用户
                UserRole userRole = UserRole.user;
                
                ILogger.d('userRole$userRole  ${logic.localParticipant.value}');
                if (logic.localParticipant.value != null) {
                  // 强制每次获取最新角色状态而不依赖缓存
                  final metadata = logic.localParticipant.value!.metadata;
                  if (metadata != null) {
                    ParticipantMetadata? parsed;
                    
                    try {
                      if (metadata is String && metadata.isNotEmpty) {
                        Map<String, dynamic> metadataMap = json.decode(metadata);
                        parsed = ParticipantMetadata.fromJson(metadataMap);
                      } else if (metadata is Map) {
                        Map<String, dynamic> metadataMap = Map<String, dynamic>.from(metadata as Map);
                        parsed = ParticipantMetadata.fromJson(metadataMap);
                      }
                    } catch (e) {
                      // 解析失败，使用默认值
                    }
                    
                    if (parsed != null) {
                      userRole = parsed.role;
                    }
                  }
                }
                
                // 只有连麦者或管理员才算在舞台上
                bool isOnStage = userRole == UserRole.publisher || userRole == UserRole.admin;
                
                return _buildCircularButton(
                  icon: Icon(
                    isOnStage ? Icons.link : Icons.link_off,
                    color: Colors.grey.shade800,
                    size: 22,
                  ),
                  size: 44.w,
                  onPressed: isOnStage
                      ? () {
                          final identity = logic.localParticipant.value?.identity;
                          if (identity != null) {
                            logic.leaveSpeakerStage(identity);
                          }
                        }
                      : () => logic.toggleRaiseHand(),
                  backgroundColor: Colors.grey.shade100,
                  gradientColors: isOnStage
                      ? [Colors.blue.shade50, Colors.blue.shade100]
                      : [Colors.grey.shade50, Colors.grey.shade200],
                );
              }));
            }

            // 聊天消息按钮 - 带通知数字
            buttons.add(Stack(
              children: [
                _buildCircularButton(
                  icon: Icon(
                      logic.isShowingChatInput.value
                          ? Icons.chat
                          : Icons.chat_outlined,
                      color: logic.isShowingChatInput.value
                          ? Colors.blue.shade700
                          : Colors.grey.shade800,
                      size: 22),
                  size: 44.w,
                  onPressed: () {
                    // 使用logic中的方法来切换聊天输入框状态
                    logic.toggleChatInput();
                  },
                  backgroundColor: Colors.grey.shade100,
                  gradientColors: logic.isShowingChatInput.value
                      ? [Colors.blue.shade50, Colors.blue.shade100]
                      : [Colors.grey.shade50, Colors.grey.shade200],
                ),
              ],
            ));

            // 参与者按钮
            buttons.add(_buildCircularButton(
              icon: Icon(Icons.people, color: Colors.grey.shade800, size: 22),
              size: 44.w,
              onPressed: () {
                _showParticipantList(context);
              },
              backgroundColor: Colors.grey.shade100,
              gradientColors: [Colors.grey.shade50, Colors.grey.shade200],
            ));

            // 根据按钮数量调整布局
            return Row(
              mainAxisAlignment: buttons.length <= 5
                  ? MainAxisAlignment.spaceAround
                  : MainAxisAlignment.spaceBetween,
              children: buttons,
            );
          }),
        ),
      ],
    );
  }

  // 圆形按钮通用构建方法
  Widget _buildCircularButton({
    required Widget icon,
    required double size,
    required Function()? onPressed,
    required Color backgroundColor,
    List<Color>? gradientColors,
  }) {
    // 根据禁用状态调整图标的颜色
    final Widget iconWidget = onPressed == null
        ? Opacity(opacity: 0.5, child: icon) // 禁用状态下降低透明度
        : icon;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        gradient: gradientColors != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          splashColor: onPressed == null
              ? Colors.transparent
              : Colors.white.withOpacity(0.3),
          highlightColor: onPressed == null
              ? Colors.transparent
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(child: iconWidget),
        ),
      ),
    );
  }

  // 从参与者对象获取用户角色
  UserRole getUserRole(lk.Participant? participant) {
    if (participant == null || participant.metadata == null) {
      return UserRole.user; // 默认为普通用户
    }

    try {
      final metadata = parseParticipantMetadata(participant);
      return metadata?.role ?? UserRole.user;
    } catch (e) {
      ILogger.e('MeetingToolbar', '获取用户角色失败: $e');
      return UserRole.user;
    }
  }

  // 从参与者对象获取用户名
  String getUserName(lk.Participant participant) {
    final metadata = parseParticipantMetadata(participant);
    return metadata?.user_name ?? participant.name ?? participant.identity;
  }

  // 解析参与者元数据
  ParticipantMetadata? parseParticipantMetadata(lk.Participant participant) {
    if (participant.metadata == null) {
      return null;
    }

    try {
      // 使用ParticipantMetadata的安全解析方法
      return ParticipantMetadata.tryParse(participant.metadata);
    } catch (e) {
      return null;
    }
  }

  // 从参与者元数据中获取头像URL
  String? getFaceURL(lk.Participant participant) {
    try {
      if (participant.metadata != null) {
        Map<String, dynamic> metadataMap;
        
        if (participant.metadata is String) {
          metadataMap = json.decode(participant.metadata as String);
          return metadataMap['faceURL'] as String?;
        } else if (participant.metadata is Map) {
          metadataMap = Map<String, dynamic>.from(participant.metadata as Map);
          return metadataMap['faceURL'] as String?;
        }
      }
    } catch (e) {
      ILogger.e('MeetingToolbar', '获取头像URL失败: $e');
    }
    return null;
  }

  // 判断当前用户是否为普通观众（非主持人、非管理员、非连麦者）
  bool _isCurrentUserRegularViewer() {
    // 如果是主持人，不是普通观众
    if (logic.isHost.value) return false;

    // 添加null检查
    if (logic.localParticipant.value == null) {
      ILogger.d('MeetingToolbar', '本地参与者为空，默认为普通观众');
      return true;
    }

    final role = getUserRole(logic.localParticipant.value);
    return role == UserRole.user;
  }

  void _showParticipantList(BuildContext context) {
    Get.bottomSheet(
      Container(
        height: 320.h, // 固定高度
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    StrRes.participantList,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20.sp,
                    ),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 参与者列表
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 构建参与者列表
                    Obx(() {
                      // 获取所有参与者
                      final List<lk.Participant> allParticipants = [];

                      // 添加本地参与者（如果存在）
                      if (logic.localParticipant.value != null) {
                        allParticipants.add(logic.localParticipant.value!);
                      }

                      // 添加远程参与者
                      allParticipants.addAll(logic.remoteParticipants);

                      // 分类参与者
                      final owners = <lk.Participant>[];
                      final admins = <lk.Participant>[];
                      final publishers = <lk.Participant>[];
                      final users = <lk.Participant>[];
                      
                      // 检查是否有本地参与者是房主
                      bool hasLocalOwner = false;
                      if (logic.localParticipant.value != null) {
                        hasLocalOwner = getUserRole(logic.localParticipant.value) == UserRole.owner;
                      }
                      
                      // 存储已处理的参与者ID，用于去重
                      final Set<String> processedIds = {};

                      for (var participant in allParticipants) {
                        // 获取参与者角色
                        final role = getUserRole(participant);
                        
                        // 获取参与者ID
                        final participantId = participant.identity;
                        
                        // 如果该参与者ID已处理过，跳过此参与者
                        if (processedIds.contains(participantId)) {
                          ILogger.d('MeetingToolbar', '跳过重复参与者: $participantId');
                          continue;
                        }
                        
                        // 标记该ID已处理
                        processedIds.add(participantId);
                        
                        // 获取是否为本地参与者
                        final bool isLocal = participant is lk.LocalParticipant;

                        switch (role) {
                          case UserRole.owner:
                            owners.add(participant);
                            break;
                          case UserRole.admin:
                            admins.add(participant);
                            break;
                          case UserRole.publisher:
                            publishers.add(participant);
                            break;
                          case UserRole.user:
                          default:
                            users.add(participant);
                            break;
                        }
                      }

                      // 构建分类列表
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (owners.isNotEmpty)
                            _buildRoleSection(StrRes.meetingRoleHost, owners),
                          if (admins.isNotEmpty)
                            _buildRoleSection(StrRes.meetingRoleAdmin, admins),
                          if (publishers.isNotEmpty)
                            _buildRoleSection(StrRes.meetingRolePublisher, publishers),
                          if (users.isNotEmpty) _buildRoleSection(StrRes.meetingRoleAudience, users),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: false,
      isDismissible: true,
      enableDrag: false,
    );
  }

  // 构建角色分组
  Widget _buildRoleSection(String title, List<lk.Participant> participants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Text(
            '$title (${participants.length})',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: title == StrRes.meetingRoleHost
                  ? Colors.red
                  : title == StrRes.meetingRoleAdmin
                      ? Colors.orange
                      : title == StrRes.meetingRolePublisher
                          ? Colors.blue
                          : Colors.grey,
            ),
          ),
        ),
        ...participants
            .map((participant) => _buildParticipantItem(participant))
            .toList(),
        SizedBox(height: 8.h),
      ],
    );
  }

  // 获取参与者音频状态
  bool getParticipantMicStatus(lk.Participant participant) {
    if (participant is lk.LocalParticipant) {
      return !logic.isMuted.value;
    } else if (participant is lk.RemoteParticipant) {
      final audioTracks = participant.trackPublications.values
          .where((pub) => pub.kind == lk.TrackType.AUDIO);
      return audioTracks.any((pub) => pub.subscribed && !pub.muted);
    }
    return false;
  }

  // 获取参与者视频状态
  bool getParticipantVideoStatus(lk.Participant participant) {
    if (participant is lk.LocalParticipant) {
      return !logic.isCameraOff.value;
    } else if (participant is lk.RemoteParticipant) {
      final videoTracks = participant.trackPublications.values
          .where((pub) => pub.kind == lk.TrackType.VIDEO);
      return videoTracks.any((pub) => pub.subscribed && !pub.muted);
    }
    return false;
  }

  // 创建菜单项
  PopupMenuItem _createMenuItem(String title, Function() onTap,
      {Color textColor = Colors.black}) {
    return PopupMenuItem(
      child: Text(title, style: TextStyle(fontSize: 13.sp, color: textColor)),
      onTap: onTap,
    );
  }

  // 构建针对管理员的菜单项
  List<PopupMenuItem> _buildAdminMenuItems(lk.Participant participant,
      ParticipantMetadata? metadata, bool isCurrentUserHost) {
    final List<PopupMenuItem> items = [];
    final userName = getUserName(participant);

    if (isCurrentUserHost) {
      items.add(_createMenuItem(StrRes.meetingToolbarRevokeAdmin, () {
        Get.back();
        logic.revokeAdmin(participant.identity, userName);
      }));

      items.add(_createMenuItem(StrRes.meetingToolbarRemoveUser, () {
        logic.blockViewer(participant.identity, userName);
      }, textColor: Colors.red));
    }

    return items;
  }

  // 构建针对连麦者的菜单项
  List<PopupMenuItem> _buildPublisherMenuItems(
      lk.Participant participant,
      ParticipantMetadata? metadata,
      bool isCurrentUserHost,
      bool isCurrentUserAdmin) {
    final List<PopupMenuItem> items = [];
    final userName = getUserName(participant);

    items.add(_createMenuItem(StrRes.meetingToolbarForceUnpublish, () {
      Get.back();
      logic.rejectRaisedHand(participant.identity, userName);
    }));

    if (isCurrentUserHost) {
      items.add(_createMenuItem(StrRes.meetingToolbarSetAsAdmin, () {
        Get.back();
        logic.setAdmin(participant.identity, userName);
      }));
    }

    items.add(_createMenuItem(StrRes.meetingToolbarRemoveUser, () {
      logic.blockViewer(participant.identity, userName);
    }, textColor: Colors.red));

    return items;
  }

  // 构建针对普通观众的菜单项
  List<PopupMenuItem> _buildUserMenuItems(
      lk.Participant participant,
      ParticipantMetadata? metadata,
      bool isCurrentUserHost,
      bool isCurrentUserAdmin) {
    final List<PopupMenuItem> items = [];
    final userName = getUserName(participant);

    items.add(_createMenuItem(StrRes.meetingToolbarInviteToStage, () {
      Get.back();
      logic.inviteToStage(participant.identity, userName);
    }));

    if (isCurrentUserHost) {
      items.add(_createMenuItem(StrRes.meetingToolbarSetAsAdmin, () {
        Get.back();
        logic.setAdmin(participant.identity, userName);
      }));
    }

    items.add(_createMenuItem(StrRes.meetingToolbarRemoveUser, () {
      logic.blockViewer(participant.identity, userName);
    }, textColor: Colors.red));

    return items;
  }

  // 构建参与者项
  Widget _buildParticipantItem(lk.Participant participant) {
    final isLocal = participant is lk.LocalParticipant;
    final participantMetadata = parseParticipantMetadata(participant);
    final userName = getUserName(participant);
    final faceURL = getFaceURL(participant);

    // 获取当前用户角色
    final currentUserRole = getUserRole(logic.localParticipant.value);
    final bool isCurrentUserHost = currentUserRole == UserRole.owner;
    final bool isCurrentUserAdmin = currentUserRole == UserRole.admin;
    final bool canManage = isCurrentUserHost || isCurrentUserAdmin;

    // 判断是否举手
    final bool isRaiseHand = participantMetadata?.hand_raised ?? false;

    // 判断参与者角色
    final participantRole = getUserRole(participant);
    final bool isOwner = participantRole == UserRole.owner;
    final bool isAdmin = participantRole == UserRole.admin;
    final bool isPublisher = participantRole == UserRole.publisher;
    final bool isUser = participantRole == UserRole.user;

    // 获取音视频状态
    bool isMicEnabled = getParticipantMicStatus(participant);
    bool isCamEnabled = getParticipantVideoStatus(participant);

    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          // 头像 - 使用faceURL
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: faceURL != null && faceURL.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    faceURL,
                    width: 32.w,
                    height: 32.w,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // 图片加载失败时显示文字头像
                      return Center(
                        child: Text(
                          userName.isNotEmpty
                              ? userName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14.sp,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Center(
                  child: Text(
                    userName.isNotEmpty
                        ? userName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
          ),
          SizedBox(width: 8.w),

          // 名称和状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$userName${isLocal ? " (${StrRes.meetingMe})" : ""}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(width: 4.w),

                    // 角色标签
                    if (participantMetadata != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: participantMetadata
                              .getRoleColor()
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          participantMetadata.getRoleLabel(),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: participantMetadata.getRoleColor(),
                          ),
                        ),
                      ),

                    // 举手图标
                    if (isRaiseHand)
                      Container(
                        margin: EdgeInsets.only(left: 4.w),
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pan_tool,
                                size: 10.sp, color: Colors.amber),
                            SizedBox(width: 2.w),
                            Text(
                              StrRes.meetingToolbarHandRaising,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // 设备状态
                Row(
                  children: [
                    Icon(
                      isMicEnabled ? Icons.mic : Icons.mic_off,
                      size: 12.sp,
                      color: isMicEnabled ? Colors.green : Colors.grey,
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      isCamEnabled ? Icons.videocam : Icons.videocam_off,
                      size: 12.sp,
                      color: isCamEnabled ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 管理按钮 - 不是自己且不是房主的情况下显示
          if (canManage && !isLocal && !isOwner)
            Container(
              width: 60.w,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 同意连麦按钮 (当对方举手时显示)
                  if (isRaiseHand)
                    IconButton(
                      icon: Icon(Icons.check_circle,
                          color: Colors.green, size: 18.sp),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        // 查找对应的举手请求并接受
                        final request = logic.raisedHands.firstWhereOrNull(
                            (req) => req.user_id == participant.identity);
                        if (request != null) {
                          logic.acceptRaisedHand(request);
                          Get.back();
                         
                        }
                      },
                    ),

                  // 管理菜单 - 根据当前用户身份和目标用户身份显示不同的选项
                  PopupMenuButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18.sp,
                    itemBuilder: (context) {
                      final menuItems = <PopupMenuItem>[];

                      // 根据参与者角色添加不同的菜单项
                      if (isAdmin) {
                        menuItems.addAll(_buildAdminMenuItems(participant,
                            participantMetadata, isCurrentUserHost));
                      } else if (isPublisher) {
                        menuItems.addAll(_buildPublisherMenuItems(
                            participant,
                            participantMetadata,
                            isCurrentUserHost,
                            isCurrentUserAdmin));
                      } else if (isUser) {
                        menuItems.addAll(_buildUserMenuItems(
                            participant,
                            participantMetadata,
                            isCurrentUserHost,
                            isCurrentUserAdmin));
                      }

                      return menuItems;
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
