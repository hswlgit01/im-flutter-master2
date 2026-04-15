import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/pages/chat/chat_search/chat_search_text/chat_search_text_logic.dart';
import 'package:openim_common/openim_common.dart';

import '../pages/chat/chat_logic.dart';
import '../pages/chat/group_setup/edit_name/edit_name_logic.dart';
import '../pages/chat/group_setup/group_member_list/group_member_list_logic.dart';
import '../pages/contacts/add_by_search/add_by_search_logic.dart';
import '../pages/contacts/group_profile_panel/group_profile_panel_logic.dart';
import '../pages/contacts/select_contacts/select_contacts_logic.dart';
import '../pages/mine/edit_my_info/edit_my_info_logic.dart';
import 'app_pages.dart';

class AppNavigator {
  AppNavigator._();

  // 用户账号缓存，key: userID, value: account
  static final Map<String, String> _userAccountCache = <String, String>{};

  /// 清除用户账号缓存
  static void clearUserAccountCache() {
    _userAccountCache.clear();
  }

  /// 移除指定用户的账号缓存
  static void removeUserAccountCache(String userID) {
    _userAccountCache.remove(userID);
  }

  static void startLogin() {
    Get.offAllNamed(AppRoutes.login);
  }

  static void startBackLogin() {
    Get.until((route) => Get.currentRoute == AppRoutes.login);
  }

  static void startMain(
      {bool isAutoLogin = false, List<ConversationInfo>? conversations}) {
    Get.offAllNamed(
      AppRoutes.home,
      arguments: {'isAutoLogin': isAutoLogin, 'conversations': conversations},
    );
  }

  static void startSplashToMain(
      {bool isAutoLogin = false, List<ConversationInfo>? conversations}) {
    Get.offAndToNamed(
      AppRoutes.home,
      arguments: {'isAutoLogin': isAutoLogin, 'conversations': conversations},
    );
  }

  static void startBackMain() {
    Get.until((route) => Get.currentRoute == AppRoutes.home);
  }

  static Future<T?>? startChat<T>({
    required ConversationInfo conversationInfo,
    bool offUntilHome = true,
    String? draftText,
    Message? searchMessage,
  }) async {
    GetTags.createChatTag();

    final arguments = {
      'draftText': draftText,
      'conversationInfo': conversationInfo,
      'searchMessage': searchMessage,
    };

    return offUntilHome
        ? Get.offNamedUntil(
            AppRoutes.chat,
            (route) => route.settings.name == AppRoutes.home,
            arguments: arguments,
          )
        : Get.toNamed(
            AppRoutes.chat,
            arguments: arguments,
            preventDuplicates: false,
          );
  }

  static Future<T?>? startChatNotification<T>(
      {required ConversationInfo conversationInfo}) async {
    final arguments = {
      'conversationInfo': conversationInfo,
    };

    return Get.toNamed(
      AppRoutes.chatNotification,
      arguments: arguments,
    );
  }

  static Future<T?>? startWebViewPage<T>(
      {required String url, String? title, bool immersive = false}) async {
    final arguments = {'url': url, 'title': title, 'immersive': immersive};

    return Get.toNamed(
      AppRoutes.webViewPage,
      arguments: arguments,
    );
  }

  static Future<T?>? startAddAcountPage<T>() async {
    return Get.toNamed(
      AppRoutes.addAcount,
    );
  }

  static startAddContactsMethod() => Get.toNamed(AppRoutes.addContactsMethod);

  static startAddContactsBySearch({required SearchType searchType}) =>
      Get.toNamed(
        AppRoutes.addContactsBySearch,
        arguments: {"searchType": searchType},
      );

  static startUserProfilePane({
    required String userID,
    String? account,
    String? groupID,
    String? nickname,
    String? faceURL,
    bool offAllWhenDelFriend = false,
    bool offAndToNamed = false,
    bool forceCanAdd = false,
  }) async {
    GetTags.createUserProfileTag();

    if (account == null) {
      // 先从缓存中查找
      account = _userAccountCache[userID];

      // 如果缓存中没有，则从API获取
      if (account == null) {
        var list = await LoadingView.singleton.wrap(
          asyncFunction: () => Apis.getUserFullInfo(
            userIDList: [userID],
            pageNumber: 1,
            showNumber: 1,
          ),
        );
        if (list != null && list.isNotEmpty) {
          account = list.first.account;
          // 将结果存入缓存
          if (account != null) {
            _userAccountCache[userID] = account;
          }
        }
      }
    }

    final arguments = {
      'groupID': groupID,
      'userID': userID,
      'account': account ?? "",
      'nickname': nickname,
      'faceURL': faceURL,
      'offAllWhenDelFriend': offAllWhenDelFriend,
      'forceCanAdd': forceCanAdd,
    };

    return offAndToNamed
        ? Get.offAndToNamed(AppRoutes.userProfilePanel, arguments: arguments)
        : Get.toNamed(
            AppRoutes.userProfilePanel,
            arguments: arguments,
            preventDuplicates: false,
          );
  }

  static startPersonalInfo({
    required String userID,
  }) =>
      Get.toNamed(AppRoutes.personalInfo, arguments: {
        'userID': userID,
      });

  static startFriendSetup({
    required String userID,
  }) =>
      Get.toNamed(AppRoutes.friendSetup, arguments: {
        'userID': userID,
      });

  static startSetFriendRemark() =>
      Get.toNamed(AppRoutes.setFriendRemark, arguments: {});

  static startSendVerificationApplication({
    String? userID,
    String? groupID,
    JoinGroupMethod? joinGroupMethod,
  }) =>
      Get.toNamed(AppRoutes.sendVerificationApplication, arguments: {
        'joinGroupMethod': joinGroupMethod,
        'userID': userID,
        'groupID': groupID,
      });

  static startGroupProfilePanel({
    required String groupID,
    required JoinGroupMethod joinGroupMethod,
    bool offAndToNamed = false,
  }) =>
      offAndToNamed
          ? Get.offAndToNamed(AppRoutes.groupProfilePanel, arguments: {
              'joinGroupMethod': joinGroupMethod,
              'groupID': groupID,
            })
          : Get.toNamed(AppRoutes.groupProfilePanel, arguments: {
              'joinGroupMethod': joinGroupMethod,
              'groupID': groupID,
            });

  static startMyInfo() => Get.toNamed(AppRoutes.myInfo);

  static startMyTeam() => Get.toNamed(AppRoutes.myTeam);

  static startEditMyInfo({EditAttr attr = EditAttr.nickname, int? maxLength}) =>
      Get.toNamed(AppRoutes.editMyInfo,
          arguments: {'editAttr': attr, 'maxLength': maxLength});

  static startAccountSetup() => Get.toNamed(AppRoutes.accountSetup);

  static startBlacklist() => Get.toNamed(AppRoutes.blacklist);

  static startLanguageSetup() => Get.toNamed(AppRoutes.languageSetup);

  static startAboutUs() => Get.toNamed(AppRoutes.aboutUs);

    static startPaymentMethod() => Get.toNamed(AppRoutes.paymentMethod);

  static startChatSetup({
    required ConversationInfo conversationInfo,
  }) =>
      Get.toNamed(AppRoutes.chatSetup, arguments: {
        'conversationInfo': conversationInfo,
      });

  static startGroupChatSetup({
    required ConversationInfo conversationInfo,
  }) =>
      Get.toNamed(AppRoutes.groupChatSetup, arguments: {
        'conversationInfo': conversationInfo,
      });

  static startGroupManage({
    required GroupInfo groupInfo,
  }) =>
      Get.toNamed(AppRoutes.groupManage, arguments: {
        'groupInfo': groupInfo,
      });

  static startEditGroupName({required EditNameType type, String? faceUrl}) =>
      Get.toNamed(AppRoutes.editGroupName, arguments: {
        'type': type,
        'faceUrl': faceUrl,
      });

  static Future<T?>? startGroupMemberList<T>({
    required GroupInfo groupInfo,
    GroupMemberOpType opType = GroupMemberOpType.view,
  }) =>
      Get.toNamed(AppRoutes.groupMemberList,
          preventDuplicates: false,
          arguments: {
            'groupInfo': groupInfo,
            'opType': opType,
          });


  static startGroupQrcode() => Get.toNamed(AppRoutes.groupQrcode);

  static startChatSearchText(ConversationInfo conversationInfo,
          {String? keyword, ToType? type = ToType.conversation}) =>
      Get.toNamed(AppRoutes.chatSearchText, arguments: {
        'conversationInfo': conversationInfo,
        'keyword': keyword,
        'type': type,
      });

  static startChatSearchImage(ConversationInfo conversationInfo) =>
      Get.toNamed(AppRoutes.chatSearchImage, arguments: {
        'conversationInfo': conversationInfo,
      });

  static startChatSearchVideo(ConversationInfo conversationInfo) =>
      Get.toNamed(AppRoutes.chatSearchVideo, arguments: {
        'conversationInfo': conversationInfo,
      });

  static startChatSearchFile(ConversationInfo conversationInfo) =>
      Get.toNamed(AppRoutes.chatSearchFile, arguments: {
        'conversationInfo': conversationInfo,
      });

  static startFriendRequests() => Get.toNamed(AppRoutes.friendRequests);

  static startProcessFriendRequests({
    required FriendApplicationInfo applicationInfo,
  }) =>
      Get.toNamed(AppRoutes.processFriendRequests, arguments: {
        'applicationInfo': applicationInfo,
      });

  static startGroupRequests() => Get.toNamed(AppRoutes.groupRequests);

  static startProcessGroupRequests({
    required GroupApplicationInfo applicationInfo,
  }) =>
      Get.toNamed(AppRoutes.processGroupRequests, arguments: {
        'applicationInfo': applicationInfo,
      });

  static startFriendList() => Get.toNamed(AppRoutes.friendList);

  static startGroupList() => Get.toNamed(AppRoutes.groupList);

  static startSelectContacts({
    required SelAction action,
    List<String>? defaultCheckedIDList,
    List<dynamic>? checkedList,
    List<String>? excludeIDList,
    bool openSelectedSheet = false,
    String? groupID,
    String? ex,
  }) =>
      Get.toNamed(AppRoutes.selectContacts, arguments: {
        'action': action,
        'defaultCheckedIDList': defaultCheckedIDList,
        'checkedList': IMUtils.convertCheckedListToMap(checkedList),
        'excludeIDList': excludeIDList,
        'openSelectedSheet': openSelectedSheet,
        'groupID': groupID,
        'ex': ex,
      });

  static startSelectContactsFromFriends() =>
      Get.toNamed(AppRoutes.selectContactsFromFriends);

  static startSelectContactsFromGroup() =>
      Get.toNamed(AppRoutes.selectContactsFromGroup);

  static startSelectContactsFromSearch() =>
      Get.toNamed(AppRoutes.selectContactsFromSearch);

  static startCreateGroup({
    List<UserInfo> defaultCheckedList = const [],
  }) async {
    final result = await startSelectContacts(
      action: SelAction.crateGroup,
      defaultCheckedIDList: defaultCheckedList.map((e) => e.userID!).toList(),
    );
    final list = IMUtils.convertSelectContactsResultToUserInfo(result);
    if (list is List<UserInfo>) {
      return Get.toNamed(
        AppRoutes.createGroup,
        arguments: {
          'checkedList': list,
          'defaultCheckedList': defaultCheckedList
        },
      );
    }
    return null;
  }

  static startGlobalSearch() => Get.toNamed(AppRoutes.globalSearch);

  static startExpandChatHistory({
    required SearchResultItems searchResultItems,
    required String defaultSearchKey,
  }) =>
      Get.toNamed(AppRoutes.expandChatHistory, arguments: {
        'searchResultItems': searchResultItems,
        'defaultSearchKey': defaultSearchKey,
      });

  static startRegister() => Get.toNamed(AppRoutes.register);

  static startLuckMoney(
      ConversationInfo conversationInfo, GroupInfo? groupInfo) {
    return Get.toNamed(AppRoutes.luckMoney, arguments: {
      'groupInfo': groupInfo,
      'conversationInfo': conversationInfo,
    });
  }

  static startLuckMoneySelectedMember(GroupInfo groupInfo) {
    return Get.toNamed(AppRoutes.selectedMemberList, arguments: {
      'groupInfo': groupInfo,
    });
  }

  // 红包详情页面，传递红包信息
  static startLuckMoneyDetail(
      {required String msgId,
      Map<String, dynamic>? data,
      bool isErrorRedirect = false}) {
    return Get.toNamed(AppRoutes.luckMoneyDetail, arguments: {
      'msg_id': msgId,
      'data': data,
      'isErrorRedirect': isErrorRedirect,
    });
  }

  static startLuckMoneyLog() {
    return Get.toNamed(AppRoutes.luckMoneyLog);
  }

  static startBackLuckMoney(GroupMembersInfo membersInfo) {
    return Get.until((route) {
      if (Get.currentRoute == AppRoutes.luckMoney) {
        Get.back(result: membersInfo);
        return true;
      }
      return false;
    });
  }

  static void startVerifyPhone({
    String? phoneNumber,
    String? email,
    required String areaCode,
    required int usedFor,
    String? invitationCode,
  }) =>
      Get.toNamed(AppRoutes.verifyPhone, arguments: {
        'phoneNumber': phoneNumber,
        'email': email,
        'areaCode': areaCode,
        'usedFor': usedFor,
        'invitationCode': invitationCode,
      });

  static void startSetPassword({
    String? phoneNumber,
    String? email,
    required String areaCode,
    required int usedFor,
    required String verificationCode,
    String? invitationCode,
  }) =>
      Get.toNamed(AppRoutes.setPassword, arguments: {
        'phoneNumber': phoneNumber,
        'email': email,
        'areaCode': areaCode,
        'usedFor': usedFor,
        'verificationCode': verificationCode,
        'invitationCode': invitationCode
      });

  static void startSetSelfInfo({
    String? phoneNumber,
    String? email,
    String? account,
    required String areaCode,
    required password,
    required int usedFor,
    required String verificationCode,
    String? invitationCode,
  }) =>
      Get.toNamed(AppRoutes.setSelfInfo, arguments: {
        'phoneNumber': phoneNumber,
        'email': email,
        'account': account,
        'areaCode': areaCode,
        'password': password,
        'usedFor': usedFor,
        'verificationCode': verificationCode,
        'invitationCode': invitationCode
      });

  static startMuteSetup({
    required String userID,
    String? groupID,
  }) {
    return Get.toNamed(AppRoutes.muteSetup,
        arguments: {"userID": userID, "groupID": groupID});
  }

  static startGroupAc({required GroupInfo groupInfo}) {
    return Get.toNamed(AppRoutes.groupAc, arguments: {
      'groupInfo': groupInfo,
    });
  }

  static startMyQrcode() {
    return Get.toNamed(AppRoutes.myQrcode);
  }

  static startForgetPassword() => Get.toNamed(AppRoutes.forgetPassword);

  static void startResetPassword({
    String? phoneNumber,
    String? email,
    String? account,
    required String areaCode,
    required String verificationCode,
  }) =>
      Get.toNamed(AppRoutes.resetPassword, arguments: {
        'phoneNumber': phoneNumber,
        'email': email,
        'account': account,
        'areaCode': areaCode,
        'usedFor': 2,
        'verificationCode': verificationCode,
      });

  static startSelectContactsFromTag() =>
      Get.toNamed(AppRoutes.selectContactsFromTag);

  static startTransfer({
    required String receiverID,
    required ChatLogic chatLogic,
  }) =>
      Get.toNamed(AppRoutes.transfer, arguments: {
        'receiverID': receiverID,
        'chatLogic': chatLogic,
      });

  static void startSearch({int index = 0}) {
    Get.toNamed(AppRoutes.search, arguments: {
      "index": index
    });
  }
  /// 账号注册
  static void startAccountRegister() {
    Get.toNamed(AppRoutes.accountRegister);
  }
  /// 前往签到页面
  static void startCheckin() {
    Get.toNamed(AppRoutes.checkin);
  }
  /// 前往奖券页面
  static void startLotteryTickets() {
    Get.toNamed(AppRoutes.lotteryTickets);
  }
  /// 前往奖品记录页面
  static void startPrizeRecords() {
    Get.toNamed(AppRoutes.prizeRecords);
  }
  /// 前往签到奖励记录页面
  static void startCheckinRewards() {
    Get.toNamed(AppRoutes.checkinRewards);
  }
  // 移除签到规则说明页面导航，规则直接显示在签到页面
  /// 前往文章
  static void startArticle({required String articleId}) {
    Get.toNamed(AppRoutes.article, arguments: {'articleId': articleId});
  }

  static Future<dynamic>? startLotteryWheel({
    required String id,
    required String lotteryTicketId,
  }) {
    return Get.toNamed(AppRoutes.lotteryWheel, arguments: {
      'id': id,
      'lottery_ticket_id': lotteryTicketId,
    });
  }
}