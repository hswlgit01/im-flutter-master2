import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';

class ChatSearchFileLogic extends GetxController {

  late Rx<ConversationInfo>? conversationInfo;
  RxList<Message> messages = <Message>[].obs;
  @override
  void onInit() async {
    if (Get.arguments['conversationInfo'] != null) {
      conversationInfo = Rx(Get.arguments['conversationInfo']);
    }
    messages.value = await _getMessages();
    super.onInit();
  }

  Future<List<Message>> _getMessages() async {
    final result = await OpenIM.iMManager.messageManager.searchLocalMessages(
      conversationID: conversationInfo?.value.conversationID,
      messageTypeList: [
        MessageType.file,
      ],
    );

    if (result.searchResultItems != null) {
      final searchResultItems = result.searchResultItems!.first;
      return searchResultItems.messageList ?? [];
    }
    return [];
  }
}