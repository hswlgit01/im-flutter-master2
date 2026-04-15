import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'meeting_logic.dart';

class MeetingTopBar extends StatelessWidget {
  final MeetingLogic logic;

  const MeetingTopBar({
    Key? key,
    required this.logic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左侧区域：头像、会议名称、会议信息
          Expanded(
            child: Row(
              children: [
                // 封面图片或主持人头像
                Obx(() => Container(
                  width: 32.r,
                  height: 32.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                  child: logic.meetingCover.value.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            logic.meetingCover.value,
                            width: 32.r,
                            height: 32.r,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // 图片加载失败时显示文字头像
                              return Center(
                                child: Text(
                                  logic.currentUserName.value.isNotEmpty ? logic.currentUserName.value[0].toUpperCase() : '?',
                                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            logic.currentUserName.value.isNotEmpty ? logic.currentUserName.value[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                )),
                SizedBox(width: 8.w),
                // 会议信息垂直排列
                Expanded(
                  child: Obx(() => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 会议标题
                      Text(
                        logic.meetingTitle.value,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      // 会议时长和人数
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.black54, size: 12.sp),
                          SizedBox(width: 2.w),
                          // 会议时长
                          Text(
                            logic.meetingDuration.value,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // 分隔符
                          Text(
                            '|',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(Icons.people, color: Colors.black54, size: 12.sp),
                          SizedBox(width: 2.w),
                          // 参与人数
                          Text(
                            '${logic.participantCount.value}人',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )),
                ),
              ],
            ),
          ),
          
          // 右侧控制区：三点菜单和关闭按钮
          Row(
            children: [
              // 三点菜单按钮
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.black87),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                offset: Offset(0, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                color: Colors.white,
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, color: Colors.blue, size: 18.sp),
                        SizedBox(width: 8.w),
                        Text(StrRes.meetingUiShareMeeting, 
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                 
                ],
                onSelected: (value) {
                  if (value == 'share') {
                    // 处理分享会议链接
                    logic.shareLiveStream();
                  } else if (value == 'settings') {
                    // 处理会议设置
                    _handleMeetingSettings();
                  }
                },
              ),
              SizedBox(width: 8.w),
              // 关闭按钮
              InkWell(
                onTap: logic.endMeeting,
                customBorder: CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Icon(Icons.close, color: Colors.black87, size: 20.sp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  

  
  // 处理会议设置
  void _handleMeetingSettings() {
    // 在这里实现会议设置逻辑
  }
}