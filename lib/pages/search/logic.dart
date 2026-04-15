import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/pages/chat/chat_search/chat_search_text/chat_search_text_logic.dart';
import 'package:openim/pages/conversation/conversation_logic.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';

class SearchLogic extends GetxController {
  final conversationLogic = Get.find<ConversationLogic>();

  final inputCtrl = TextEditingController();
  final index = 0.obs;

  RxBool friendLoading = false.obs;
  final friends = <SearchFriendsInfo>[].obs;

  RxBool groupLoading = false.obs;
  final groups = <GroupInfo>[].obs;

  RxBool chatTextLoading = false.obs;
  final chatTexts = <SearchResultItems>[].obs;

  RxBool chatFileLoading = false.obs;
  final chatFiles = <Message>[].obs;

  @override
  onReady() {
    final arguments = Get.arguments;
    index.value = arguments['index'];
  }

  switchTab(int i) {
    index.value = i;
  }

  submit() async {
    LoadingView.singleton.show();
    searchFriend();
    searchGroup();
    searchChatText();
    searchChatFile();
    LoadingView.singleton.dismiss();
  }

  toFriendDetail(SearchFriendsInfo info) {
    AppNavigator.startUserProfilePane(
      userID: info.userID!,
      nickname: info.nickname,
      faceURL: info.faceURL,
    );
  }

  void toGroupChat(GroupInfo info) {
    conversationLogic.toChat(
      offUntilHome: false,
      groupID: info.groupID,
      nickname: info.groupName,
      faceURL: info.faceURL,
      sessionType: info.sessionType,
    );
  }

  void toChatText(SearchResultItems searchResultItems) async {
    final reslut = await LoadingView.singleton.wrap(
        asyncFunction: () =>
            OpenIM.iMManager.conversationManager.getMultipleConversation(
              conversationIDList: [searchResultItems.conversationID!],
            ));
    if (reslut.isNotEmpty) {
      AppNavigator.startChatSearchText(reslut.first!,
          keyword: inputCtrl.text, type: ToType.global);
    }
  }

  previewFile(Message message) {
    IMUtils.previewFile(message);
  }

  Future<dynamic> searchFriend() async {
    friendLoading.value = true;
    friends.clear();
    final reslut = await OpenIM.iMManager.friendshipManager.searchFriends(
        keywordList: [inputCtrl.text],
        isSearchNickname: true,
        isSearchRemark: true,
        isSearchUserID: true);
    friendLoading.value = false;
    friends.addAll(reslut);
  }

  searchGroup() async {
    groupLoading.value = true;
    groups.clear();
    final reslut = await OpenIM.iMManager.groupManager.searchGroups(
        keywordList: [inputCtrl.text],
        isSearchGroupID: true,
        isSearchGroupName: true);
    groupLoading.value = false;
    groups.addAll(reslut);
  }

  searchChatText() async {
    chatTextLoading.value = true;
    chatTexts.clear();
    final reslut = await OpenIM.iMManager.messageManager.searchLocalMessages(
      keywordList: [inputCtrl.text],
      messageTypeList: [
        MessageType.text,
        MessageType.atText,
        MessageType.quote,
      ],
    );

    chatTextLoading.value = false;
    chatTexts.addAll(reslut.searchResultItems ?? []);
  }

  searchChatFile() async {
    chatFileLoading.value = true;
    chatFiles.clear();
    final reslut = await OpenIM.iMManager.messageManager.searchLocalMessages(
      keywordList: [inputCtrl.text],
      messageTypeList: [
        MessageType.file,
      ],
    );
    List<Message> messages = [];
    for (SearchResultItems element in reslut.searchResultItems ?? []) {
      messages.addAll(element.messageList ?? []);
    }
    chatFileLoading.value = false;
    chatFiles.addAll(messages);
  }
}
