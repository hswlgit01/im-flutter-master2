import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'meeting_logic.dart';
import 'dart:convert';

class MeetingChatArea extends StatelessWidget {
  final MeetingLogic logic;

  const MeetingChatArea({
    Key? key,
    required this.logic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildChatContent();
  }

  // 聊天内容区域
  Widget _buildChatContent() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 顶部标题
          _buildHeaderTitle(),
          
          // 置顶消息区域 - 只对房主和管理员可见
          Obx(() => logic.raisedHands.isNotEmpty && logic.isHostOrAdmin()
            ? _buildPinnedRequests() 
            : SizedBox.shrink()
          ),
          
          // 聊天消息列表
          Expanded(
            child: Obx(() {
              if (logic.messages.isEmpty) {
                return _buildEmptyChatView();
              } else {
                // 创建消息列表的副本，然后反转它以便最新的消息显示在顶部
                final messageList = List<ChatMessage>.from(logic.messages);
                messageList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  itemCount: messageList.length,
                  itemBuilder: (context, index) {
                    return _buildChatMessage(messageList[index]);
                  },
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  // 顶部标题
  Widget _buildHeaderTitle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 18.sp, color: Colors.grey.shade700),
          SizedBox(width: 6.w),
          Obx(() => Text(
            StrRes.meetingUIAudience.replaceFirst('%s', logic.participantCount.value.toString()),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          )),
          Spacer(),
          // 角落显示"聊天中"标签
          // Container(
          //   padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          //   decoration: BoxDecoration(
          //     color: Colors.blue.withOpacity(0.1),
          //     borderRadius: BorderRadius.circular(10.r),
          //   ),
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       Icon(Icons.chat_bubble_outline, size: 12.sp, color: Colors.blue),
          //       SizedBox(width: 2.w),
          //       Text(
          //         '聊天中',
          //         style: TextStyle(
          //           fontSize: 12.sp,
          //           color: Colors.blue,
          //           fontWeight: FontWeight.w500,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  // 置顶的上麦请求
  Widget _buildPinnedRequests() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          // 请求标题
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.record_voice_over, size: 14.sp, color: Colors.blue.shade700),
                SizedBox(width: 4.w),
                Text(
                  StrRes.meetingUISpeakingRequest,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
                Spacer(),
                Text(
                  StrRes.meetingUIRequestCount.replaceFirst('%s', logic.raisedHands.length.toString()),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
          
          // 请求列表
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: logic.raisedHands.length > 2 ? 2 : logic.raisedHands.length,
              itemBuilder: (context, index) {
                final request = logic.raisedHands[index];
                return Container(
                  margin: EdgeInsets.only(bottom: index < logic.raisedHands.length - 1 ? 6.h : 0),
                  child: Row(
                    children: [
                      // 头像
                      _buildAvatar(request.user_name, faceURL: _getFaceURLByUserId(request.user_id)),
                      SizedBox(width: 8.w),
                      // 用户信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              request.user_name,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 操作按钮
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRequestActionButton(
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            onTap: () {
                              // 同意上麦
                              logic.acceptRaisedHand(request);
                            },
                          ),
                          SizedBox(width: 6.w),
                          _buildRequestActionButton(
                            icon: Icons.cancel_outlined,
                            color: Colors.red.shade400,
                            onTap: () {
                              // 拒绝上麦
                              logic.rejectRaisedHand(request.user_id,request.user_name);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // 如果有更多请求，显示查看全部
          if (logic.raisedHands.length > 2)
            InkWell(
              onTap: () {
                // 显示全部上麦请求
                _showAllRaisedHandRequests(Get.context!);
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(7.r)),
                ),
                alignment: Alignment.center,
                child: Text(
                  StrRes.meetingUIViewAllRequests.replaceFirst('%s', logic.raisedHands.length.toString()),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 显示所有举手请求的对话框
  void _showAllRaisedHandRequests(BuildContext context) {
    // 确保只有房主和管理员可以查看所有举手请求
    if (!logic.isHostOrAdmin()) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.record_voice_over, size: 20.sp, color: Colors.blue),
            SizedBox(width: 8.w),
            Text(
              StrRes.meetingUIAllSpeakingRequests,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Obx(() => ListView.builder(
            shrinkWrap: true,
            itemCount: logic.raisedHands.length,
            itemBuilder: (context, index) {
              final request = logic.raisedHands[index];
              return ListTile(
                leading: _buildAvatar(request.user_name, faceURL: _getFaceURLByUserId(request.user_id)),
                title: Text(request.user_name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: () {
                        // 同意上麦
                        logic.acceptRaisedHand(request);
                        Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.cancel_outlined, color: Colors.red),
                      onPressed: () {
                        // 拒绝上麦
                        logic.rejectRaisedHand(request.user_id,request.user_name);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(StrRes.meetingUIClose),
          ),
        ],
      ),
    );
  }

  // 上麦请求操作按钮
  Widget _buildRequestActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 24.w,
        height: 24.w,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16.sp,
          color: color,
        ),
      ),
    );
  }

  // 聊天消息列表为空时的视图
  Widget _buildEmptyChatView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 40.sp,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 8.h),
          Text(
            StrRes.meetingUIEmptyChat,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // 构建聊天消息
  Widget _buildChatMessage(ChatMessage message) {
    final isSystem = message.sender == StrRes.meetingSystemSender;
    
    if (isSystem) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4.h),
        alignment: Alignment.center,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11.sp,
            ),
          ),
        ),
      );
    }
    
    // 格式化时间
    final timeString = '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';
    
  
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户头像 - 直接使用消息中的faceURL
          _buildAvatar(message.sender, faceURL: message.faceURL),
          SizedBox(width: 8.w),
          // 消息内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用户信息和时间
                Row(
                  children: [
                    Text(
                      message.sender,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (message.role.isNotEmpty) ...[
                      SizedBox(width: 4.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: _getRoleColor(message.role),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          message.role,
                          style: TextStyle(
                            color: _getRoleTextColor(message.role),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    Spacer(),
                    Text(
                      timeString,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                // 消息文本
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8.r),
                      bottomLeft: Radius.circular(8.r),
                      bottomRight: Radius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 获取角色背景颜色
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case '主持人':
      case 'host':
        return Colors.blue.withOpacity(0.1);
      case '管理员':
      case 'admin':
        return Colors.orange.withOpacity(0.1);
      case '参与者':
      case 'publisher':
        return Colors.green.withOpacity(0.1);
      case 'system':
        return Colors.grey.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  // 获取角色文本颜色
  Color _getRoleTextColor(String role) {
    switch (role.toLowerCase()) {
      case '主持人':
      case 'host':
        return Colors.blue;
      case '管理员':
      case 'admin':
        return Colors.orange;
      case '参与者':
      case 'publisher':
        return Colors.green;
      case 'system':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
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
  
  // 创建头像组件，优先使用faceURL
  Widget _buildAvatar(String userName, {String? faceURL, double radius = 14}) {
    if (faceURL != null && faceURL.isNotEmpty) {
      return CircleAvatar(
        radius: radius.r,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(faceURL),
        onBackgroundImageError: (e, stackTrace) {
          print('加载头像图片失败: $e');
        },
      );
    } else {
      return CircleAvatar(
        radius: radius.r,
        backgroundColor: _getAvatarColor(userName),
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }
  
  // 从参与者ID查找头像URL
  String? _getFaceURLByUserId(String userId) {
    // 查找本地参与者
    if (logic.localParticipant.value?.identity == userId) {
      try {
        if (logic.localParticipant.value?.metadata != null) {
          var metadataMap = _parseMetadataMap(logic.localParticipant.value!.metadata);
          return metadataMap?['faceURL'] as String?;
        }
      } catch (e) {
        print('获取本地参与者头像失败: $e');
      }
    }
    
    // 查找远程参与者
    for (var participant in logic.remoteParticipants) {
      if (participant.identity == userId) {
        try {
          if (participant.metadata != null) {
            var metadataMap = _parseMetadataMap(participant.metadata);
            return metadataMap?['faceURL'] as String?;
          }
        } catch (e) {
          print('获取远程参与者头像失败: $e');
        }
      }
    }
    
    return null;
  }
  
  // 解析元数据
  Map<String, dynamic>? _parseMetadataMap(dynamic metadata) {
    try {
      if (metadata is String) {
        return json.decode(metadata);
      } else if (metadata is Map) {
        return Map<String, dynamic>.from(metadata as Map);
      }
    } catch (e) {
      print('解析元数据失败: $e');
    }
    return null;
  }
} 