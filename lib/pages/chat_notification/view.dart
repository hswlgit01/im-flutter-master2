import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import './logic.dart';
import 'widget/notification_item_view.dart';

/// 系统通知
class ChatNotificationPage extends StatelessWidget {
  final logic = Get.find<ChatNotificationLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles.c_F0F2F6,
      appBar: TitleBar.back(
        title: logic.nickname.value,
      ),
      body: SafeArea(
        child: Obx(() {
          return WaterMarkBgView(
              text: '',
              backgroundColor: Styles.c_F8F9FA,
              child: ChatListView(
                  itemCount: logic.messageList.length,
                  controller: logic.scrollController,
                  onScrollToBottomLoad: logic.onScrollToBottomLoad,
                  itemBuilder: (context, index) {
                    final message = logic.indexOfMessage(index);
                    return Obx(() => _buildItemView(message));
                  }));
        }),
      ),
    );
  }

  Widget _buildItemView(Message message) {
    return NotificationItemView(
      key: logic.itemKey(message),
      textScaleFactor: logic.scaleFactor.value,
      message: message,
      visibilityChange: (msg, visible) {
        logic.markMessageAsRead(message, visible);
      },
      onTap: () {
        logic.onTapMessage(message);
      },
    );
  }
}
