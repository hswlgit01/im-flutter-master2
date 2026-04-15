import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

enum ToType {
  conversation,
  global
}

class ChatSearchTextLogic extends GetxController {
  final controller = RefreshController();
  final inputCtrl = TextEditingController();
  late Rx<ConversationInfo>? conversationInfo;
  RxString searchText = "".obs;
  ToType toType = ToType.conversation;
  RxList<Message> messageList = <Message>[].obs;
  int pageIndex = 0;

  @override
  void onInit() async {
    if (Get.arguments['conversationInfo'] != null) {
      conversationInfo = Rx(Get.arguments['conversationInfo']);
    }
    if (Get.arguments['keyword'] != null) {
      searchText.value = Get.arguments['keyword'];
      inputCtrl.text = searchText.value;
    }
    if (Get.arguments['type'] != null) {
      toType = Get.arguments['type'];
    }
    if (toType == ToType.global) {
      onLoad();
    }
    super.onInit();
  }

  onLoad() async {
    pageIndex++;
    final list = await _getMessages();
    messageList.addAll(list);

    if (list.isEmpty) {
      controller.loadNoData();
    } else {
      controller.loadComplete();
    }
  }

  reset() {
    pageIndex = 0;
    messageList.clear();
    onLoad();
  }

  onMessageTap(Message message) {
    if (conversationInfo?.value != null) {
      AppNavigator.startChat(
        conversationInfo: conversationInfo!.value,
        searchMessage: message,
        offUntilHome: false
      );
    }
  }

  searchImage() {
    if (conversationInfo?.value != null) {
      AppNavigator.startChatSearchImage(conversationInfo!.value);
    }
  }

  searchVideo() {
    if (conversationInfo?.value != null) {
      AppNavigator.startChatSearchVideo(conversationInfo!.value);
    }
  }

  searchFile() {
    if (conversationInfo?.value != null) {
      AppNavigator.startChatSearchVideo(conversationInfo!.value);
    }
  }

  Future<List<Message>> _getMessages() async {
    final result = await OpenIM.iMManager.messageManager.searchLocalMessages(
      keywordList: [searchText.value],
      conversationID: conversationInfo?.value.conversationID,
      messageTypeList: [
        MessageType.text,
        MessageType.atText,
        MessageType.quote,
      ],
      pageIndex: pageIndex,
      count: 100,
    );

    if (result.searchResultItems != null) {
      final searchResultItems = result.searchResultItems!.first;
      return searchResultItems.messageList ?? [];
    }
    return [];
  }
}
