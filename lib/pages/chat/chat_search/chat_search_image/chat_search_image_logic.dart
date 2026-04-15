import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class ChatSearchImageLogic extends GetxController {

  late Rx<ConversationInfo>? conversationInfo;
  final RxMap<String, List<Message>> messageMap = <String, List<Message>>{}.obs;
  @override
  void onInit() async {
    if (Get.arguments['conversationInfo'] != null) {
      conversationInfo = Rx(Get.arguments['conversationInfo']);
    }
    messageMap.value = IMUtils.groupingMessage(await _getMessages());
    super.onInit();
  }

  Future<List<Message>> _getMessages() async {
    final result = await OpenIM.iMManager.messageManager.searchLocalMessages(
      conversationID: conversationInfo?.value.conversationID,
      messageTypeList: [
        MessageType.picture,
      ],
    );

    if (result.searchResultItems != null) {
      final searchResultItems = result.searchResultItems!.first;
      return searchResultItems.messageList ?? [];
    }
    return [];
  }
}