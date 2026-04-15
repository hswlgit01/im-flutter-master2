import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'meeting_logic.dart';
import 'meeting_top_bar.dart';
import 'meeting_video_area.dart';
import 'meeting_chat_area.dart';
import 'meeting_toolbar.dart';

class MeetingPage extends StatefulWidget {
  MeetingPage({Key? key}) : super(key: key);

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> {
  final logic = Get.put(MeetingLogic());
  final FocusNode _chatFocusNode = FocusNode();
  bool _isKeyboardVisible = false;
  
  @override
  void initState() {
    super.initState();
    _chatFocusNode.addListener(_onFocusChange);
  }
  
  @override
  void dispose() {
    _chatFocusNode.removeListener(_onFocusChange);
    _chatFocusNode.dispose();
    
    // 确保页面销毁时断开房间连接
    try {
      logic.endMeeting();
    } catch (e) {
      // 忽略错误，因为可能已经断开连接了
    }
    
    super.dispose();
  }
  
  void _onFocusChange() {
    if (!_chatFocusNode.hasFocus) {
      logic.isShowingChatInput.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardNowVisible = bottomInset > 0;
    
    if (_isKeyboardVisible && !isKeyboardNowVisible && logic.isShowingChatInput.value) {
      Future.microtask(() => logic.isShowingChatInput.value = false);
    }
    
    _isKeyboardVisible = isKeyboardNowVisible;
    
    return WillPopScope(
      onWillPop: () async {
        if (logic.isShowingChatInput.value) {
          logic.hideChatInput();
          return false;
        }
        logic.endMeeting();
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // 主内容区域
              Column(
                children: [
                  MeetingTopBar(logic: logic),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: MeetingVideoArea(logic: logic),
                  ),
                  Expanded(
                    child: MeetingChatArea(logic: logic),
                  ),
                  MeetingToolbar(logic: logic),
                ],
              ),
              
              // 聊天输入区域
              Obx(() {
                if (logic.isShowingChatInput.value) {
                  // 当显示聊天输入时自动请求焦点
                  WidgetsBinding.instance?.addPostFrameCallback((_) {
                    _chatFocusNode.requestFocus();
                  });
                  
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildChatInputArea(context),
                  );
                } else {
                  return SizedBox.shrink();
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  // 简化聊天输入区域
  Widget _buildChatInputArea(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Row(
          children: [
            SizedBox(width: 16.w),
            Expanded(
              child: TextField(
                controller: logic.messageController,
                focusNode: _chatFocusNode,
                decoration: InputDecoration(
                  hintText: StrRes.message,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  prefixIcon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey.shade500),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: Colors.blue),
              onPressed: _sendMessage,
            ),
            SizedBox(width: 8.w),
          ],
        ),
      ),
    );
  }
  
  void _sendMessage() {
    if (logic.messageController.text.trim().isNotEmpty) {
      logic.sendChatMessage();
    }
    logic.hideChatInput();
  }
} 