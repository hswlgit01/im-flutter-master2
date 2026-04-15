import 'dart:ui';

import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

import 'lang/en_US.dart';
import 'lang/zh_CN.dart';
import 'lang/zh-HK.dart';

class TranslationService extends Translations {
  static Locale? get locale => Get.deviceLocale;
  static const fallbackLocale = Locale('en', 'US');

  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': en_US,
        'zh_CN': zh_CN,
        'zh_HK': zh_HK
      };
}

class StrRes {
  StrRes._();

  static String get welcome => 'welcome'.tr;

  static String get phoneNumber => 'phoneNumber'.tr;
  static String get userID => 'userID'.tr;

  static String get plsEnterPhoneNumber => 'plsEnterPhoneNumber'.tr;

  static String get password => 'password'.tr;

  static String get plsEnterPassword => 'plsEnterPassword'.tr;

  static String get account => 'account'.tr;

  static String get plsEnterAccount => 'plsEnterAccount'.tr;

  static String get plsEnterEmail => 'plsEnterEmail'.tr;

  static String get forgetPassword => 'forgetPassword'.tr;

  static String get verificationCodeLogin => 'verificationCodeLogin'.tr;

  static String get login => 'login'.tr;

  static String get noAccountYet => 'noAccountYet'.tr;

  static String get loginNow => 'loginNow'.tr;

  static String get registerNow => 'registerNow'.tr;

  static String get accountPasswordRegister => 'accountPasswordRegister'.tr;

  static String get emailRegisterUser => 'emailRegisterUser'.tr;

  static String get lockPwdErrorHint => 'lockPwdErrorHint'.tr;

  static String get newUserRegister => 'newUserRegister'.tr;

  static String get verificationCode => 'verificationCode'.tr;

  static String get sendVerificationCode => 'sendVerificationCode'.tr;

  static String get resendVerificationCode => 'resendVerificationCode'.tr;

  static String get verificationCodeTimingReminder =>
      'verificationCodeTimingReminder'.tr;

  static String get defaultVerificationCode => 'defaultVerificationCode'.tr;
  static String get plsEnterVerificationCode => 'plsEnterVerificationCode'.tr;

  static String get emailVerificationHint => 'emailVerificationHint'.tr;

  static String get plsSendVerificationCodeFirst => 'plsSendVerificationCodeFirst'.tr;

  static String get verificationCodeVerifyFailed => 'verificationCodeVerifyFailed'.tr;

  static String get verificationCodeSent => 'verificationCodeSent'.tr;

  static String get invitationCode => 'invitationCode'.tr;

  static String get plsEnterInvitationCode => 'plsEnterInvitationCode'.tr;

  static String get optional => 'optional'.tr;

  static String get nextStep => 'nextStep'.tr;

  static String get plsEnterRightPhone => 'plsEnterRightPhone'.tr;

  static String get plsEnterRightPhoneOrEmail => 'plsEnterRightPhoneOrEmail'.tr;

  static String get enterVerificationCode => 'enterVerificationCode'.tr;

  static String get setPassword => 'setPassword'.tr;

  static String get plsConfirmPasswordAgain => 'plsConfirmPasswordAgain'.tr;

  static String get confirmPassword => 'confirmPassword'.tr;

  static String get wrongPasswordFormat => 'wrongPasswordFormat'.tr;

  static String get accountFormatError => 'accountFormatError'.tr;

  static String get accountFormatHint => 'accountFormatHint'.tr;

  static String get plsCompleteInfo => 'plsCompleteInfo'.tr;

  static String get plsEnterYourNickname => 'plsEnterYourNickname'.tr;

  static String get setInfo => 'setInfo'.tr;

  static String get loginPwdFormat => 'loginPwdFormat'.tr;
  static String get loginPwdFormat6t => 'loginPwdFormat6t'.tr;
  

  static String get passwordLogin => 'passwordLogin'.tr;

  static String get through => 'through'.tr;

  static String get rememberPassword => 'rememberPassword'.tr;

  static String get home => 'home'.tr;

  static String get contacts => 'contacts'.tr;

  static String get workbench => 'workbench'.tr;

  static String get mine => 'mine'.tr;

  static String get draftText => 'draftText'.tr;

  static String get everyone => 'everyone'.tr;

  static String get you => 'you'.tr;

  static String get someoneMentionYou => 'someoneMentionYou'.tr;

  static String get groupAc => 'groupAc'.tr;

  static String get createGroupNtf => 'createGroupNtf'.tr;

  static String get editGroupInfoNtf => 'editGroupInfoNtf'.tr;

  static String get quitGroupNtf => 'quitGroupNtf'.tr;

  static String get invitedJoinGroupNtf => 'invitedJoinGroupNtf'.tr;

  static String get kickedGroupNtf => 'kickedGroupNtf'.tr;

  static String get joinGroupNtf => 'joinGroupNtf'.tr;

  static String get dismissGroupNtf => 'dismissGroupNtf'.tr;

  static String get transferredGroupNtf => 'transferredGroupNtf'.tr;

  static String get muteMemberNtf => 'muteMemberNtf'.tr;

  static String get muteCancelMemberNtf => 'muteCancelMemberNtf'.tr;

  static String get muteGroupNtf => 'muteGroupNtf'.tr;

  static String get muteCancelGroupNtf => 'muteCancelGroupNtf'.tr;

  static String get friendAddedNtf => 'friendAddedNtf'.tr;

  static String get openPrivateChatNtf => 'openPrivateChatNtf'.tr;

  static String get closePrivateChatNtf => 'closePrivateChatNtf'.tr;

  static String get meetingEnableVideo => 'meetingEnableVideo'.tr;

  static String get memberInfoChangedNtf => 'memberInfoChangedNtf'.tr;

  static String get unsupportedMessage => 'unsupportedMessage'.tr;

  static String get otherMessage => 'otherMessage'.tr;

  static String get picture => 'picture'.tr;

  static String get video => 'video'.tr;

  static String get voice => 'voice'.tr;

  static String get location => 'location'.tr;

  static String get file => 'file'.tr;

  static String get carte => 'carte'.tr;

  static String get groupCard => 'groupCard'.tr;

  static String get emoji => 'emoji'.tr;

  static String get chatRecord => 'chatRecord'.tr;

  static String get revokeMsg => 'revokeMsg'.tr;

  static String get aRevokeBMsg => 'aRevokeBMsg'.tr;

  static String get blockedByFriendHint => 'blockedByFriendHint'.tr;

  static String get deletedByFriendHint => 'deletedByFriendHint'.tr;

  static String get sendFriendVerification => 'sendFriendVerification'.tr;

  static String get removedFromGroupHint => 'removedFromGroupHint'.tr;

  static String get groupDisbanded => 'groupDisbanded'.tr;

  static String get search => 'search'.tr;

  static String get synchronizing => 'synchronizing'.tr;

  static String get syncFailed => 'syncFailed'.tr;

  static String get connecting => 'connecting'.tr;

  static String get connectionFailed => 'connectionFailed'.tr;

  static String get top => 'top'.tr;

  static String get cancelTop => 'cancelTop'.tr;

  static String get markHasRead => 'markHasRead'.tr;

  static String get delete => 'delete'.tr;

  static String get nPieces => 'nPieces'.tr;

  static String get online => 'online'.tr;

  static String get offline => 'offline'.tr;

  static String get phoneOnline => 'phoneOnline'.tr;

  static String get pcOnline => 'pcOnline'.tr;

  static String get webOnline => 'webOnline'.tr;

  static String get webMiniOnline => 'webMiniOnline'.tr;

  static String get upgradeFind => 'upgradeFind'.tr;

  static String get upgradeVersion => 'upgradeVersion'.tr;

  static String get upgradeDescription => 'upgradeDescription'.tr;

  static String get upgradeIgnore => 'upgradeIgnore'.tr;

  static String get upgradeLater => 'upgradeLater'.tr;

  static String get upgradeNow => 'upgradeNow'.tr;

  static String get upgradePermissionTips => 'upgradePermissionTips'.tr;

  static String get inviteYouCall => 'inviteYouCall'.tr;

  static String get rejectCall => 'rejectCall'.tr;

  static String get acceptCall => 'acceptCall'.tr;

  static String get callVoice => 'callVoice'.tr;

  static String get callVideo => 'callVideo'.tr;

  static String get sentSuccessfully => 'sentSuccessfully'.tr;

  static String get copySuccessfully => 'copySuccessfully'.tr;

  static String get copyFailed => 'copyFailed'.tr;

  static String get day => 'day'.tr;

  static String get hour => 'hour'.tr;

  static String get hours => 'hours'.tr;

  static String get minute => 'minute'.tr;

  static String get seconds => 'seconds'.tr;

  static String get cancel => 'cancel'.tr;

  static String get determine => 'determine'.tr;

  static String get toolboxAlbum => 'toolboxAlbum'.tr;

  static String get toolboxCall => 'toolboxCall'.tr;

  static String get toolboxCamera => 'toolboxCamera'.tr;

  static String get toolboxPocket => 'toolboxPocket'.tr;

  static String get toolboxRedEnvelope => 'toolboxRedEnvelope'.tr;

  static String get toolboxCard => 'toolboxCard'.tr;

  static String get toolboxFile => 'toolboxFile'.tr;

  static String get toolboxLocation => 'toolboxLocation'.tr;

  static String get toolboxDirectionalMessage => 'toolboxDirectionalMessage'.tr;

  static String get send => 'send'.tr;

  static String get holdTalk => 'holdTalk'.tr;

  static String get releaseToSend => 'releaseToSend'.tr;

  static String get releaseToSendSwipeUpToCancel =>
      'releaseToSendSwipeUpToCancel'.tr;

  static String get liftFingerToCancelSend => 'liftFingerToCancelSend'.tr;

  static String get callDuration => 'callDuration'.tr;

  static String get cancelled => 'cancelled'.tr;

  static String get cancelledByCaller => 'cancelledByCaller'.tr;

  static String get rejectedByCaller => 'rejectedByCaller'.tr;

  static String get callTimeout => 'callTimeout'.tr;

  static String get rejected => 'rejected'.tr;

  static String get networkAnomaly => 'networkAnomaly'.tr;

  static String get forwardMaxCountHint => 'forwardMaxCountHint'.tr;

  static String get typing => 'typing'.tr;

  static String get addSuccessfully => 'addSuccessfully'.tr;

  static String get addFailed => 'addFailed'.tr;

  static String get setSuccessfully => 'setSuccessfully'.tr;

  static String get callingBusy => 'callingBusy'.tr;

  static String get callHandledByOtherDevice => 'callHandledByOtherDevice'.tr;

  static String get groupCallHint => 'groupCallHint'.tr;

  static String get joinIn => 'joinIn'.tr;

  static String get menuCopy => 'menuCopy'.tr;

  static String get menuDel => 'menuDel'.tr;

  static String get menuForward => 'menuForward'.tr;

  static String get menuReply => 'menuReply'.tr;

  static String get menuMulti => 'menuMulti'.tr;

  static String get menuRevoke => 'menuRevoke'.tr;

  static String get menuAdd => 'menuAdd'.tr;

  static String get muteTimeCannotBeLessThanZero => 'muteTimeCannotBeLessThanZero'.tr;

  static String get nMessage => 'nMessage'.tr;

  static String get plsSelectLocation => 'plsSelectLocation'.tr;

  static String get groupAudioCallHint => 'groupAudioCallHint'.tr;

  static String get groupVideoCallHint => 'groupVideoCallHint'.tr;

  static String get reEdit => 'reEdit'.tr;

  static String get download => 'download'.tr;

  static String get playSpeed => 'playSpeed'.tr;

  static String get googleMap => 'googleMap'.tr;

  static String get appleMap => 'appleMap'.tr;

  static String get baiduMap => 'baiduMap'.tr;

  static String get amapMap => 'amapMap'.tr;

  static String get tencentMap => 'tencentMap'.tr;

  static String get offlineMeetingMessage => 'offlineMeetingMessage'.tr;

  static String get offlineMessage => 'offlineMessage'.tr;

  static String get offlineCallMessage => 'offlineCallMessage'.tr;

  static String get logoutHint => 'logoutHint'.tr;

  static String get myInfo => 'myInfo'.tr;

  static String get workingCircle => 'workingCircle'.tr;

  static String get accountSetup => 'accountSetup'.tr;

  static String get aboutUs => 'aboutUs'.tr;

  static String get logout => 'logout'.tr;

  static String get qrcode => 'qrcode'.tr;

  static String get qrcodeHint => 'qrcodeHint'.tr;

  static String get favoriteFace => 'favoriteFace'.tr;

  static String get favoriteManage => 'favoriteManage'.tr;

  static String get favoriteCount => 'favoriteCount'.tr;

  static String get favoriteDel => 'favoriteDel'.tr;

  static String get hasRead => 'hasRead'.tr;

  static String get unread => 'unread'.tr;

  static String get nPersonUnRead => 'nPersonUnRead'.tr;

  static String get allRead => 'allRead'.tr;

  static String get messageRecipientList => 'messageRecipientList'.tr;

  static String get hasReadCount => 'hasReadCount'.tr;

  static String get unreadCount => 'unreadCount'.tr;

  static String get newFriend => 'newFriend'.tr;

  static String get newGroup => 'newGroup'.tr;

  static String get newGroupRequest => 'newGroupRequest'.tr;

  static String get myFriend => 'myFriend'.tr;

  static String get myGroup => 'myGroup'.tr;

  static String get add => 'add'.tr;

  static String get scan => 'scan'.tr;

  static String get scanHint => 'scanHint'.tr;

  static String get addFriend => 'addFriend'.tr;

  static String get addFriendHint => 'addFriendHint'.tr;

  static String get createGroup => 'createGroup'.tr;

  static String get createGroupHint => 'createGroupHint'.tr;

  static String get addGroup => 'addGroup'.tr;

  static String get addGroupHint => 'addGroupHint'.tr;

  static String get searchIDAddFriend => 'searchIDAddFriend'.tr;

  static String get searchIDAddGroup => 'searchIDAddGroup'.tr;

  static String get searchIDIs => 'searchIDIs'.tr;

  static String get searchPhoneIs => 'searchPhoneIs'.tr;

  static String get searchEmailIs => 'searchEmailIs'.tr;

  static String get searchNicknameIs => 'searchNicknameIs'.tr;

  static String get searchGroupNicknameIs => 'searchGroupNicknameIs'.tr;

  static String get noFoundUser => 'noFoundUser'.tr;

  static String get noFoundGroup => 'noFoundGroup'.tr;

  static String get joinGroupMethod => 'joinGroupMethod'.tr;

  static String get joinGroupDate => 'joinGroupDate'.tr;

  static String get byInviteJoinGroup => 'byInviteJoinGroup'.tr;

  static String get byIDJoinGroup => 'byIDJoinGroup'.tr;

  static String get byQrcodeJoinGroup => 'byQrcodeJoinGroup'.tr;

  static String get groupID => 'groupID'.tr;

  static String get setAsAdmin => 'setAsAdmin'.tr;

  static String get setMute => 'setMute'.tr;

  static String get organizationInfo => 'organizationInfo'.tr;

  static String get organization => 'organization'.tr;

  static String get department => 'department'.tr;

  static String get position => 'position'.tr;

  static String get personalInfo => 'personalInfo'.tr;

  static String get audioAndVideoCall => 'audioAndVideoCall'.tr;

  static String get sendMessage => 'sendMessage'.tr;

  static String get viewDynamics => 'viewDynamics'.tr;

  static String get avatar => 'avatar'.tr;

  static String get name => 'name'.tr;

  static String get nickname => 'nickname'.tr;

  static String get gender => 'gender'.tr;

  static String get englishName => 'englishName'.tr;

  static String get birthDay => 'birthDay'.tr;

  static String get tel => 'tel'.tr;

  static String get mobile => 'mobile'.tr;

  static String get email => 'email'.tr;

  static String get man => 'man'.tr;

  static String get woman => 'woman'.tr;

  static String get friendSetup => 'friendSetup'.tr;

  static String get setupRemark => 'setupRemark'.tr;

  static String get recommendToFriend => 'recommendToFriend'.tr;

  static String get addToBlacklist => 'addToBlacklist'.tr;

  static String get unfriend => 'unfriend'.tr;

  static String get areYouSureDelFriend => 'areYouSureDelFriend'.tr;

  static String delFriendHint(String nickname) => sprintf('delFriendHint'.tr, [nickname]);

  static String get areYouSureAddBlacklist => 'areYouSureAddBlacklist'.tr;

  static String get remark => 'remark'.tr;

  static String get save => 'save'.tr;

  static String get saving => 'saving'.tr;

  static String get saveSuccessfully => 'saveSuccessfully'.tr;

  static String get saveFailed => 'saveFailed'.tr;

  static String get groupVerification => 'groupVerification'.tr;

  static String get friendVerification => 'friendVerification'.tr;

  static String get sendEnterGroupApplication => 'sendEnterGroupApplication'.tr;

  static String get sendToBeFriendApplication => 'sendToBeFriendApplication'.tr;

  static String get sendSuccessfully => 'sendSuccessfully'.tr;

  static String get sendFailed => 'sendFailed'.tr;

  static String get canNotAddFriends => 'canNotAddFriends'.tr;

  static String get mutedAll => 'mutedAll'.tr;

  static String get tenMinutes => 'tenMinutes'.tr;

  static String get oneHour => 'oneHour'.tr;

  static String get twelveHours => 'twelveHours'.tr;

  static String get oneDay => 'oneDay'.tr;

  static String get custom => 'custom'.tr;

  static String get unmute => 'unmute'.tr;

  static String get youMuted => 'youMuted'.tr;

  static String get groupMuted => 'groupMuted'.tr;

  static String get notDisturbMode => 'notDisturbMode'.tr;

  static String get allowRing => 'allowRing'.tr;

  static String get allowVibrate => 'allowVibrate'.tr;

  static String get forbidAddMeToFriend => 'forbidAddMeToFriend'.tr;

  static String get blacklist => 'blacklist'.tr;

  static String get unlockSettings => 'unlockSettings'.tr;

  static String get changePassword => 'changePassword'.tr;

  static String get changePasswordSuccess => 'changePasswordSuccess'.tr;

  static String get clearChatHistory => 'clearChatHistory'.tr;

  static String get confirmClearChatHistory => 'confirmClearChatHistory'.tr;

  static String get languageSetup => 'languageSetup'.tr;

  static String get language => 'language'.tr;

  static String get english => 'english'.tr;

  static String get chinese => 'chinese'.tr;

  static String get traditionalChinese => 'traditionalChinese'.tr;

  static String get followSystem => 'followSystem'.tr;

  static String get blacklistEmpty => 'blacklistEmpty'.tr;

  static String get remove => 'remove'.tr;

  static String get fingerprint => 'fingerprint'.tr;

  static String get gesture => 'gesture'.tr;

  static String get biometrics => 'biometrics'.tr;

  static String get plsEnterPwd => 'plsEnterPwd'.tr;

  static String get plsEnterOldPwd => 'plsEnterOldPwd'.tr;

  static String get plsEnterNewPwd => 'plsEnterNewPwd'.tr;

  static String get plsConfirmNewPwd => 'plsConfirmNewPwd'.tr;

  static String get reset => 'reset'.tr;

  static String get oldPwd => 'oldPwd'.tr;

  static String get newPwd => 'newPwd'.tr;

  static String get confirmNewPwd => 'confirmNewPwd'.tr;

  static String get plsEnterConfirmPwd => 'plsEnterConfirmPwd'.tr;

  static String get twicePwdNoSame => 'twicePwdNoSame'.tr;

  static String get newPwdSameAsOld => 'newPwdSameAsOld'.tr;

  static String get changedSuccessfully => 'changedSuccessfully'.tr;

  static String get checkNewVersion => 'checkNewVersion'.tr;

  static String get chatContent => 'chatContent'.tr;

  static String get topContacts => 'topContacts'.tr;

  static String get messageNotDisturb => 'messageNotDisturb'.tr;

  static String get messageNotDisturbHint => 'messageNotDisturbHint'.tr;

  static String get burnAfterReading => 'burnAfterReading'.tr;

  static String get timeSet => 'timeSet'.tr;

  static String get setChatBackground => 'setChatBackground'.tr;

  static String get setDefaultBackground => 'setDefaultBackground'.tr;

  static String get fontSize => 'fontSize'.tr;

  static String get little => 'little'.tr;

  static String get standard => 'standard'.tr;

  static String get big => 'big'.tr;

  static String get thirtySeconds => 'thirtySeconds'.tr;

  static String get fiveMinutes => 'fiveMinutes'.tr;

  static String get clearAll => 'clearAll'.tr;

  static String get clearSuccessfully => 'clearSuccessfully'.tr;

  static String get clearCache => 'clearCache'.tr;

  static String get clearCacheConfirm => 'clearCacheConfirm'.tr;

  static String get clearCacheSuccess => 'clearCacheSuccess'.tr;

  static String get clearCacheSuccessRestart => 'clearCacheSuccessRestart'.tr;
  
  static String get messageTooLargeRecovered => 'messageTooLargeRecovered'.tr;


  static String get groupChatSetup => 'groupChatSetup'.tr;

  static String get viewAllGroupMembers => 'viewAllGroupMembers'.tr;

  static String get groupManage => 'groupManage'.tr;

  static String get myGroupMemberNickname => 'myGroupMemberNickname'.tr;

  static String get topChat => 'topChat'.tr;

  static String get muteAllMember => 'muteAllMember'.tr;

  static String get exitGroup => 'exitGroup'.tr;

  static String get dismissGroup => 'dismissGroup'.tr;

  static String get dismissGroupHint => 'dismissGroupHint'.tr;

  static String get quitGroupHint => 'quitGroupHint'.tr;

  static String get joinGroupSet => 'joinGroupSet'.tr;

  static String get allowAnyoneJoinGroup => 'allowAnyoneJoinGroup'.tr;

  static String get inviteNotVerification => 'inviteNotVerification'.tr;

  static String get needVerification => 'needVerification'.tr;

  static String get noOneCanJoin => 'noOneCanJoin'.tr;

  static String get groupNotAllowJoinHint => 'groupNotAllowJoinHint'.tr;

  static String get addMember => 'addMember'.tr;

  static String get delMember => 'delMember'.tr;

  static String get groupOwner => 'groupOwner'.tr;

  static String get groupAdmin => 'groupAdmin'.tr;

  static String get notAllowSeeMemberProfile => 'notAllowSeeMemberProfile'.tr;

  static String get notAllAddMemberToBeFriend => 'notAllAddMemberToBeFriend'.tr;

  static String get transferGroupOwnerRight => 'transferGroupOwnerRight'.tr;

  static String get groupMemberPermission => 'groupMemberPermission'.tr;

  static String get allowAnyoneViewMemberProfile => 'allowAnyoneViewMemberProfile'.tr;

  static String get disallowViewMemberCountAndList => 'disallowViewMemberCountAndList'.tr;

  static String get disallowAdminViewMembers => 'disallowAdminViewMembers'.tr;

  static String get plsEnterRightEmail => 'plsEnterRightEmail'.tr;

  static String get plsEnterRightAccount => 'plsEnterRightAccount'.tr;

  static String get groupName => 'groupName'.tr;

  static String get groupAcPermissionTips => 'groupAcPermissionTips'.tr;

  static String get plsEnterGroupAc => 'plsEnterGroupAc'.tr;

  static String get edit => 'edit'.tr;

  static String get publish => 'publish'.tr;

  static String get groupMember => 'groupMember'.tr;

  static String get selectedPeopleCount => 'selectedPeopleCount'.tr;

  static String get confirmSelectedPeople => 'confirmSelectedPeople'.tr;

  static String get confirm => 'confirm'.tr;

  static String get confirmTransferGroupToUser =>
      'confirmTransferGroupToUser'.tr;

  static String get removeGroupMember => 'removeGroupMember'.tr;

  static String get searchNotResult => 'searchNotResult'.tr;

  static String get groupQrcode => 'groupQrcode'.tr;

  static String get groupQrcodeHint => 'groupQrcodeHint'.tr;

  static String get approved => 'approved'.tr;

  static String get accept => 'accept'.tr;

  static String get reject => 'reject'.tr;

  static String get waitingForVerification => 'waitingForVerification'.tr;

  static String get rejectSuccessfully => 'rejectSuccessfully'.tr;

  static String get rejectFailed => 'rejectFailed'.tr;

  static String get applyJoin => 'applyJoin'.tr;

  static String get enterGroup => 'enterGroup'.tr;

  static String get applyReason => 'applyReason'.tr;

  static String get invite => 'invite'.tr;

  static String get sourceFrom => 'sourceFrom'.tr;

  static String get byMemberInvite => 'byMemberInvite'.tr;

  static String get bySearch => 'bySearch'.tr;

  static String get byScanQrcode => 'byScanQrcode'.tr;

  static String get iCreatedGroup => 'iCreatedGroup'.tr;

  static String get iJoinedGroup => 'iJoinedGroup'.tr;

  static String get nPerson => 'nPerson'.tr;

  static String get searchNotFound => 'searchNotFound'.tr;

  static String get organizationStructure => 'organizationStructure'.tr;

  static String get recentConversations => 'recentConversations'.tr;

  static String get selectAll => 'selectAll'.tr;

  static String get plsEnterGroupNameHint => 'plsEnterGroupNameHint'.tr;

  static String get completeCreation => 'completeCreation'.tr;

  static String get sendCarteConfirmHint => 'sendCarteConfirmHint'.tr;

  static String get sentSeparatelyTo => 'sentSeparatelyTo'.tr;

  static String get sentTo => 'sentTo'.tr;

  static String get leaveMessage => 'leaveMessage'.tr;

  static String get mergeForwardHint => 'mergeForwardHint'.tr;

  static String get mergeForward => 'mergeForward'.tr;

  static String get quicklyFindChatHistory => 'quicklyFindChatHistory'.tr;

  static String get notFoundChatHistory => 'notFoundChatHistory'.tr;

  static String get globalSearchAll => 'globalSearchAll'.tr;

  static String get globalSearchContacts => 'globalSearchContacts'.tr;

  static String get globalSearchGroup => 'globalSearchGroup'.tr;

  static String get globalSearchChatHistory => 'globalSearchChatHistory'.tr;

  static String get chatHistoryBetween => 'chatHistoryBetween'.tr;

  static String get globalSearchChatFile => 'globalSearchChatFile'.tr;

  static String get relatedChatHistory => 'relatedChatHistory'.tr;

  static String get seeMoreRelatedContacts => 'seeMoreRelatedContacts'.tr;

  static String get seeMoreRelatedGroup => 'seeMoreRelatedGroup'.tr;

  static String get seeMoreRelatedChatHistory => 'seeMoreRelatedChatHistory'.tr;

  static String get seeMoreRelatedFile => 'seeMoreRelatedFile'.tr;

  static String get publishPicture => 'publishPicture'.tr;

  static String get publishVideo => 'publishVideo'.tr;

  static String get mentioned => 'mentioned'.tr;

  static String get comment => 'comment'.tr;

  static String get like => 'like'.tr;

  static String get reply => 'reply'.tr;

  static String get rollUp => 'rollUp'.tr;

  static String get fullText => 'fullText'.tr;

  static String get selectAssetsFromCamera => 'selectAssetsFromCamera'.tr;

  static String get selectAssetsFromAlbum => 'selectAssetsFromAlbum'.tr;

  static String get selectAssetsFirst => 'selectAssetsFirst'.tr;

  static String get whoCanWatch => 'whoCanWatch'.tr;

  static String get remindWhoToWatch => 'remindWhoToWatch'.tr;

  static String get public => 'public'.tr;

  static String get everyoneCanSee => 'everyoneCanSee'.tr;

  static String get partiallyVisible => 'partiallyVisible'.tr;

  static String get visibleToTheSelected => 'visibleToTheSelected'.tr;

  static String get partiallyInvisible => 'partiallyInvisible'.tr;

  static String get invisibleToTheSelected => 'invisibleToTheSelected'.tr;

  static String get private => 'private'.tr;

  static String get onlyVisibleToMe => 'onlyVisibleToMe'.tr;

  static String get selectVideoLimit => 'selectVideoLimit'.tr;

  static String get selectContactsLimit => 'selectContactsLimit'.tr;

  static String get message => 'message'.tr;

  static String get commentedYou => 'commentedYou'.tr;
  static String get commentedWho => 'commentedWho'.tr;

  static String get likedYou => 'likedYou'.tr;

  static String get mentionedYou => 'mentionedYou'.tr;
  static String get mentionedWho => 'mentionedWho'.tr;

  static String get replied => 'replied'.tr;

  static String get detail => 'detail'.tr;

  static String get totalNPicture => 'totalNPicture'.tr;

  static String get noDynamic => 'noDynamic'.tr;

  static String get callRecords => 'callRecords'.tr;

  static String get allCall => 'allCall'.tr;

  static String get missedCall => 'missedCall'.tr;

  static String get incomingCall => 'incomingCall'.tr;

  static String get outgoingCall => 'outgoingCall'.tr;

  static String get microphone => 'microphone'.tr;

  static String get speaker => 'speaker'.tr;

  static String get hangUp => 'hangUp'.tr;

  static String get pickUp => 'pickUp'.tr;

  static String get waitingCallHint => 'waitingCallHint'.tr;

  static String get waitingVoiceCallHint => 'waitingVoiceCallHint'.tr;

  static String get invitedVoiceCallHint => 'invitedVoiceCallHint'.tr;

  static String get waitingVideoCallHint => 'waitingVideoCallHint'.tr;

  static String get invitedVideoCallHint => 'invitedVideoCallHint'.tr;

  static String get waitingToAnswer => 'waitingToAnswer'.tr;

  static String get invitedYouToCall => 'invitedYouToCall'.tr;

  static String get calling => 'calling'.tr;

  static String get nPeopleCalling => 'nPeopleCalling'.tr;

  static String get busyVideoCallHint => 'busyVideoCallHint'.tr;

  static String get inviterBusyVideoCallHint => 'inviterBusyVideoCallHint'.tr;

  static String get whoInvitedVoiceCallHint => 'whoInvitedVoiceCallHint'.tr;

  static String get whoInvitedVideoCallHint => 'whoInvitedVideoCallHint'.tr;

  static String get plsInputMeetingSubject => 'plsInputMeetingSubject'.tr;

  static String get meetingStartTime => 'meetingStartTime'.tr;

  static String get meetingDuration => 'meetingDuration'.tr;

  static String get enterMeeting => 'enterMeeting'.tr;

  static String get meetingNo => 'meetingNo'.tr;

  static String get yourMeetingName => 'yourMeetingName'.tr;

  static String get plsInputMeetingNo => 'plsInputMeetingNo'.tr;

  static String get plsInputYouMeetingName => 'plsInputYouMeetingName'.tr;

  static String get meetingSubjectIs => 'meetingSubjectIs'.tr;

  static String get meetingStartTimeIs => 'meetingStartTimeIs'.tr;

  static String get meetingDurationIs => 'meetingDurationIs'.tr;

  static String get meetingHostIs => 'meetingHostIs'.tr;

  static String get meetingNoIs => 'meetingNoIs'.tr;

  static String get meetingMessageClickHint => 'meetingMessageClickHint'.tr;

  static String get meetingMessage => 'meetingMessage'.tr;

  static String get openMeeting => 'openMeeting'.tr;

  static String get didNotStart => 'didNotStart'.tr;

  static String get started => 'started'.tr;

  static String get meetingInitiatorIs => 'meetingInitiatorIs'.tr;

  static String get meetingDetail => 'meetingDetail'.tr;

  static String get meetingOrganizerIs => 'meetingOrganizerIs'.tr;

  static String get updateMeetingInfo => 'updateMeetingInfo'.tr;

  static String get cancelMeeting => 'cancelMeeting'.tr;

  static String get videoMeeting => 'videoMeeting'.tr;

  static String get joinMeeting => 'joinMeeting'.tr;

  static String get bookAMeeting => 'bookAMeeting'.tr;

  static String get quickMeeting => 'quickMeeting'.tr;

  static String get confirmTheChanges => 'confirmTheChanges'.tr;

  static String get invitesYouToVideoConference =>
      'invitesYouToVideoConference'.tr;

  static String get over => 'over'.tr;

  static String get meetingMute => 'meetingMute'.tr;

  static String get meetingUnmute => 'meetingUnmute'.tr;

  static String get meetingCloseVideo => 'meetingCloseVideo'.tr;

  static String get meetingOpenVideo => 'meetingOpenVideo'.tr;

  static String get meetingEndSharing => 'meetingEndSharing'.tr;

  static String get meetingShareScreen => 'meetingShareScreen'.tr;

  static String get meetingMembers => 'meetingMembers'.tr;

  static String get settings => 'settings'.tr;

  static String get leaveMeeting => 'leaveMeeting'.tr;

  static String get endMeeting => 'endMeeting'.tr;

  static String get leaveMeetingConfirmHint => 'leaveMeetingConfirmHint'.tr;

  static String get endMeetingConfirmHit => 'endMeetingConfirmHit'.tr;

  static String get meetingSettings => 'meetingSettings'.tr;

  static String get allowMembersOpenMic => 'allowMembersOpenMic'.tr;

  static String get allowMembersOpenVideo => 'allowMembersOpenVideo'.tr;

  static String get onlyHostShareScreen => 'onlyHostShareScreen'.tr;

  static String get onlyHostInviteMember => 'onlyHostInviteMember'.tr;

  static String get defaultMuteMembers => 'defaultMuteMembers'.tr;

  static String get pinThisMember => 'pinThisMember'.tr;

  static String get unpinThisMember => 'unpinThisMember'.tr;

  static String get allSeeHim => 'allSeeHim'.tr;

  static String get cancelAllSeeHim => 'cancelAllSeeHim'.tr;

  static String get muteAll => 'muteAll'.tr;

  static String get unmuteAll => 'unmuteAll'.tr;

  static String get members => 'members'.tr;

  static String get screenShare => 'screenShare'.tr;

  static String get screenShareHint => 'screenShareHint'.tr;

  static String get meetingClosedHint => 'meetingClosedHint'.tr;

  static String get meetingIsOver => 'meetingIsOver'.tr;

  static String get networkError => 'networkError'.tr;

  static String get shareSuccessfully => 'shareSuccessfully'.tr;

  static String get notFoundMinP => 'notFoundMinP'.tr;

  static String get notSendMessageNotInGroup => 'notSendMessageNotInGroup'.tr;

  static String get whoModifyGroupName => 'whoModifyGroupName'.tr;

  static String get accountWarn => 'accountWarn'.tr;

  static String get accountException => 'accountException'.tr;

  static String get verifyBeforeCheckin => 'verifyBeforeCheckin'.tr;

  static String get tagGroup => 'tagGroup'.tr;

  static String get issueNotice => 'issueNotice'.tr;

  static String get createTagGroup => 'createTagGroup'.tr;

  static String get plsEnterTagGroupName => 'plsEnterTagGroupName'.tr;

  static String get tagGroupMember => 'tagGroupMember'.tr;

  static String get completeEdit => 'completeEdit'.tr;

  static String get emptyTagGroup => 'emptyTagGroup'.tr;

  static String get confirmDelTagGroupHint => 'confirmDelTagGroupHint'.tr;

  static String get editTagGroup => 'editTagGroup'.tr;

  static String get newBuild => 'newBuild'.tr;

  static String get receiveMember => 'receiveMember'.tr;

  static String get emptyNotification => 'emptyNotification'.tr;

  static String get notificationReceiver => 'notificationReceiver'.tr;

  static String get sendAnother => 'sendAnother'.tr;

  static String get confirmDelTagNotificationHint =>
      'confirmDelTagNotificationHint'.tr;

  static String get contentNotBlank => 'contentNotBlank'.tr;

  static String get plsEnterDescription => 'plsEnterDescription'.tr;

  static String get gifNotSupported => 'gifNotSupported'.tr;

  static String get lookOver => 'lookOver'.tr;

  static String get clickToView => 'clickToView'.tr;

  static String get groupRequestHandled => 'groupRequestHandled'.tr;

  static String get burnAfterReadingDescription =>
      'burnAfterReadingDescription'.tr;

  static String get periodicallyDeleteMessage => 'periodicallyDeleteMessage'.tr;

  static String get periodicallyDeleteMessageDescription =>
      'periodicallyDeleteMessageDescription'.tr;

  static String get nDay => 'nDay'.tr;

  static String get nWeek => 'nWeek'.tr;

  static String get nMonth => 'nMonth'.tr;

  static String get talkTooShort => 'talkTooShort'.tr;

  static String get quoteContentBeRevoked => 'quoteContentBeRevoked'.tr;

  static String get tapTooShort => 'tapTooShort'.tr;
  static String get createGroupTips => 'createGroupTips'.tr;
  static String get likedWho => 'likedWho'.tr;
  static String get otherCallHandle => 'otherCallHandle'.tr;
  static String get uploadErrorLog => 'uploadErrorLog'.tr;
  static String get uploaded => 'uploaded'.tr;
  static String get uploadLogWithLine => 'uploadLogWithLine'.tr;
  static String get setLines => 'setLines'.tr;

  static String get sdkApiAddress => 'sdkApiAddress'.tr;
  static String get sdkWsAddress => 'sdkWsAddress'.tr;
  static String get appAddress => 'appAddress'.tr;
  static String get serverAddress => 'serverAddress'.tr;
  static String get switchToIP => 'switchToIP'.tr;
  static String get switchToDomain => 'switchToDomain'.tr;
  static String get serverSettingTips => 'serverSettingTips'.tr;
  static String get logLevel => 'logLevel'.tr;
  static String get callFail => 'callFail'.tr;
  static String get searchByPhoneAndUid => 'search_by_phone_and_uid'.tr;
  static String get specialMessage => 'special_message'.tr;
  static String get editGroupName => 'edit_group_name'.tr;
  static String get editGroupTips => 'edit_group_tips'.tr;
  static String get tokenInvalid => 'tokenInvalid'.tr;
  static String get supportsTypeHint => 'supportsTypeHint'.tr;
  static String get permissionDeniedTitle => 'permissionDeniedTitle'.tr;
  static String get permissionDeniedHint => 'permissionDeniedHint'.tr;
  static String get camera => 'camera'.tr;
  static String get gallery => 'gallery'.tr;
  static String get notification => 'notification'.tr;
  static String get externalStorage => 'externalStorage'.tr;
  static String get monday => 'monday'.tr;
  static String get tuesday => 'tuesday'.tr;
  static String get wednesday => 'wednesday'.tr;
  static String get thursday => 'thursday'.tr;
  static String get friday => 'friday'.tr;
  static String get saturday => 'saturday'.tr;
  static String get sunday => 'sunday'.tr;
  static String get participantRemovedHit => 'participantRemovedHit'.tr;
  static String get hasBeenSet => 'hasBeenSet'.tr;
  static String get lockMeeting => 'lockMeeting'.tr;
  static String get lockMeetingHint => 'lockMeetingHint'.tr;
  static String get voiceMotivation => 'voiceMotivation'.tr;
  static String get voiceMotivationHint => 'voiceMotivationHint'.tr;
  static String get meetingIsLocked => 'meetingIsLocked'.tr;
  static String get today => 'today'.tr;
  static String get meetingIsEnded => 'meetingIsEnded'.tr;
  static String get oneXnViews => 'oneXnViews'.tr;
  static String get twoXtwoViews => 'twoXtwoViews'.tr;
  static String get threeXthreeViews => 'threeXthreeViews'.tr;
  static String get appointNewHost => 'appointNewHost'.tr;
  static String get appointNewHostHint => 'appointNewHostHint'.tr;
  static String get gridView => 'gridView'.tr;
  static String get gridViewHint => 'gridViewHint'.tr;
  static String get requestXDoHint => 'requestXDoHint'.tr;
  static String get keepClose => 'keepClose'.tr;
  static String get cancelMeetingConfirmHit => 'cancelMeetingConfirmHit'.tr;
  static String get iKnew => 'iKnew'.tr;
  static String get assignAndLeave => 'assignAndLeave'.tr;
  static String get muteAllHint => 'muteAllHint'.tr;
  static String get inProgressByTerminalHint => 'inProgressByTerminalHint'.tr;
  static String get restore => 'restore'.tr;
  static String get done => 'done'.tr;
  static String get networkNotStable => 'networkNotStable'.tr;
  static String get otherNetworkNotStableHint => 'otherNetworkNotStableHint'.tr;
  static String get callingInterruption => 'callingInterruption'.tr;
  static String get meeting => 'meeting'.tr;
  static String get directedTo => 'directedTo'.tr;
  static String get wallet => 'wallet'.tr;
  static String get verifyIdentity => 'verifyIdentity'.tr;
  static String get paymentPassword => 'paymentPassword'.tr;
  static String get updatedOn => 'updatedOn'.tr;
  
  // Meeting roles
  static String get meetingRoleHost => 'meeting.role.host'.tr;
  static String get meetingRoleAdmin => 'meeting.role.admin'.tr;
  static String get meetingRolePublisher => 'meeting.role.publisher'.tr;
  static String get meetingRoleAudience => 'meeting.role.audience'.tr;
  
  // Meeting system messages
  static String get meetingSystemDisconnected => 'meeting.system.disconnected'.tr;
  static String get meetingSystemHostInviteStage => 'meeting.system.host_invite_stage'.tr;
  static String get meetingSystemSender => 'meeting.system.sender'.tr;
  
  // Meeting user related
  static String get meetingUserUnknown => 'meeting.user.unknown'.tr;
  static String get meetingUserThisUser => 'meeting.user.this_user'.tr;
  
  // Meeting operation status
  static String get meetingStatusAdminGranted => 'meeting.status.admin_granted'.tr;
  static String get meetingStatusConnectedSuccess => 'meeting.status.connected_success'.tr;
  static String get meetingStatusHandRaised => 'meeting.status.hand_raised'.tr;
  static String get meetingStatusProcessed => 'meeting.status.processed'.tr;
  static String get meetingStatusOperationFailed => 'meeting.status.operation_failed'.tr;
  static String get meetingStatusDemoted => 'meeting.status.demoted'.tr;
  static String get meetingStatusEndSpeaking => 'meeting.status.end_speaking'.tr;
  static String get meetingStatusInvited => 'meeting.status.invited'.tr;
  static String get meetingStatusInviteAudience => 'meeting.status.invite_audience'.tr;
  static String get meetingStatusPreparing => 'meeting.status.preparing'.tr;
  static String get meetingStatusRejected => 'meeting.status.rejected'.tr;
  static String get meetingStatusRejectInvite => 'meeting.status.reject_invite'.tr;
  static String get meetingStatusShareSuccess => 'meeting.status.share_success'.tr;
  static String get meetingStatusCopied => 'meeting.status.copied'.tr;
  
  // Meeting UI elements
  static String get meetingUiInviteTitle => 'meeting.ui.invite_title'.tr;
  static String get meetingUiReject => 'meeting.ui.reject'.tr;
  static String get meetingUiAccept => 'meeting.ui.accept'.tr;
  static String get meetingUiConfirmExit => 'meeting.ui.confirm_exit'.tr;
  static String get meetingUiConfirm => 'meeting.ui.confirm'.tr;
  static String get meetingUiCancel => 'meeting.ui.cancel'.tr;
  static String get meetingUiConfirmRemove => 'meeting.ui.confirm_remove'.tr;
  static String get meetingUiConfirmRemoveTitle => 'meeting.ui.confirm_remove_title'.tr;
  static String get meetingUiStreamEnded => 'meeting.ui.stream_ended'.tr;
  static String get meetingUiConfirmButton => 'meeting.ui.confirm_button'.tr;
  static String get meetingUiShareTitle => 'meeting.ui.share_title'.tr;
  static String get meetingUiShareMeeting => 'meeting.ui.share_meeting'.tr;
  static String get meetingUiShareToFriend => 'meeting.ui.share_to_friend'.tr;
  static String get meetingUiCopyLink => 'meeting.ui.copy_link'.tr;
  
  // Meeting statistics
  static String get meetingStatsDuration => 'meeting.stats.duration'.tr;
  static String get meetingStatsViewers => 'meeting.stats.viewers'.tr;
  static String get meetingStatsPerson => 'meeting.stats.person'.tr;
  static String get meetingStatsMaxOnline => 'meeting.stats.max_online'.tr;
  static String get meetingStatsHandCount => 'meeting.stats.hand_count'.tr;
  static String get meetingStatsTimes => 'meeting.stats.times'.tr;
  static String get meetingStatsStageCount => 'meeting.stats.stage_count'.tr;
  
  // Error messages
  static String get meetingErrorMetadataFormat => 'meeting.error.metadata_format'.tr;
  
  // More meeting related getters
  static String get meetingStatusRequestSpeaking => 'meeting.status.request_speaking'.tr;
  static String get meetingStatusUserApproved => 'meeting.status.user_approved'.tr;
  static String get meetingStatusUserRemoved => 'meeting.status.user_removed'.tr;
  static String get meetingStatusUserRevokedAdmin => 'meeting.status.user_revoked_admin'.tr;
  static String get meetingStatusUserSetAdmin => 'meeting.status.user_set_admin'.tr;
  static String get meetingStatusOperationNotSuccessful => 'meeting.status.operation_not_successful'.tr;
  static String get meetingStatusDemoteFailed => 'meeting.status.demote_failed'.tr;
  static String get meetingStatusRevokeAdminFailed => 'meeting.status.revoke_admin_failed'.tr;
  static String get meetingStatusSetAdminFailed => 'meeting.status.set_admin_failed'.tr;
  
  static String get meetingUiConfirmExitHost => 'meeting.ui.confirm_exit_host'.tr;
  static String get meetingUiConfirmExitMember => 'meeting.ui.confirm_exit_member'.tr;
  
  static String get meetingStatsEndSummary => 'meeting.stats.end_summary'.tr;
  static String get meetingStatsRequestHandled => 'meeting.stats.request_handled'.tr;

  static String get meetingStatusRevokeFailed => 'meeting.status.revoke_admin_failed'.tr;
  static String get meetingStatusRemoveFailed => 'meeting.status.remove_failed'.tr;
  static String get meetingStatusJoined => 'meeting.status.joined'.tr;
  static String get meetingStatusLeft => 'meeting.status.left'.tr;
  static String get meetingStatusUserRemovedFromMeeting => 'meeting.status.user_removed_from_meeting'.tr;
  static String get welcomeToJoin => 'meeting.ui.welcome_to_join'.tr;
  static String get meetingStatusAdminGrantedMsg => 'meeting.ui.meetingStatusAdminGrantedMsg'.tr;
  static String get meetingStatusConnectedSuccessMsg => 'meeting.ui.meetingStatusConnectedSuccessMsg'.tr;
  static String get clickTheLinkToJoin => 'meeting.ui.clickTheLinkToJoin'.tr;


  // 直播相关
  static String get permitCameraAndMic => 'permitCameraAndMic'.tr;
  static String get initLiveDevicesFailed => 'initLiveDevicesFailed'.tr;
  static String get reminder => 'reminder'.tr;
  static String get plsEnterLiveTitle => 'plsEnterLiveTitle'.tr;
  static String get liveWelcomeDefault => 'liveWelcomeDefault'.tr;
  static String get success => 'success'.tr;
  static String get liveStarted => 'liveStarted'.tr;
  static String get createLiveFailed => 'createLiveFailed'.tr;
  static String get error => 'error'.tr;
  static String get startLiveFailed => 'startLiveFailed'.tr;
  
  // 直播页面视图
  static String get startLiveStream => 'startLiveStream'.tr;
  static String get liveSettings => 'liveSettings'.tr;
  static String get liveTitle => 'liveTitle'.tr;
  static String get enterLiveTitle => 'enterLiveTitle'.tr;
  static String get liveDescription => 'liveDescription'.tr;
  static String get enterLiveDescription => 'enterLiveDescription'.tr;
  static String get deviceAndInteractionSettings => 'deviceAndInteractionSettings'.tr;
  static String get enableChat => 'enableChat'.tr;
  static String get allowAudienceParticipation => 'allowAudienceParticipation'.tr;
  static String get audienceParticipationDescription => 'audienceParticipationDescription'.tr;
  static String get frontCamera => 'frontCamera'.tr;
  static String get backCamera => 'backCamera'.tr;
  static String get cameraDisabled => 'cameraDisabled'.tr;
  static String get enableCameraToPreview => 'enableCameraToPreview'.tr;

  // 会议聊天区域
  static String get meetingUIAudience => 'meeting.ui.audience'.tr;
  static String get meetingUISpeakingRequest => 'meeting.ui.speaking_request'.tr;
  static String get meetingUIRequestCount => 'meeting.ui.request_count'.tr;
  static String get meetingUIViewAllRequests => 'meeting.ui.view_all_requests'.tr;
  static String get meetingUIAllSpeakingRequests => 'meeting.ui.all_speaking_requests'.tr;
  static String get meetingUIClose => 'meeting.ui.close'.tr;
  static String get meetingUIEmptyChat => 'meeting.ui.empty_chat'.tr;

  // 添加会议参与者列表相关
  static String get participantList => 'participantList'.tr;
  static String get meetingStatusInvite => 'meeting.status.invite'.tr;
  
  // 会议视频区域
  static String get meetingViewerOnly => 'meeting.view.viewer_only'.tr;
  static String get meetingNoParticipants => 'meeting.view.no_participants'.tr;
  static String get meetingScreenShareEnded => 'meeting.view.screen_share_ended'.tr;
  static String get meetingScreenShareLoading => 'meeting.view.screen_share_loading'.tr;
  static String get meetingCameraOff => 'meeting.view.camera_off'.tr;
  static String get meetingScreenSharing => 'meeting.view.screen_sharing'.tr;
  static String get meetingFullscreen => 'meeting.view.fullscreen'.tr;
  static String get meetingScreenOf => 'meeting.view.screen_of'.tr;
  static String get meetingMe => 'meeting.view.me'.tr;
  
  // 会议工具栏相关
  static String get meetingToolbarRevokeAdmin => 'meeting.toolbar.revoke_admin'.tr;
  static String get meetingToolbarRemoveUser => 'meeting.toolbar.remove_user'.tr;
  static String get meetingToolbarForceUnpublish => 'meeting.toolbar.force_unpublish'.tr;
  static String get meetingToolbarSetAsAdmin => 'meeting.toolbar.set_as_admin'.tr;
  static String get meetingToolbarInviteToStage => 'meeting.toolbar.invite_to_stage'.tr;
  static String get meetingToolbarHandRaising => 'meeting.toolbar.hand_raising'.tr;
  
  static String get uploadCoverSuccess => 'meeting.uploadCoverSuccess'.tr;
  static String get uploadCoverFailed => 'meeting.uploadCoverFailed'.tr;
  static String get uploadCover => 'meeting.uploadCover'.tr;

  
  // 直播页面相关
  static String get livePage => 'live.page'.tr;
  static String get liveJoin => 'live.join'.tr;
  static String get liveEnterRoomID => 'live.enter_room_id'.tr;
  static String get liveRoomIDHint => 'live.room_id_hint'.tr;
  static String get liveEmptyRoomID => 'live.empty_room_id'.tr;
  static String get liveJoinFailed => 'live.join_failed'.tr;
  static String get liveCreate => 'live.create'.tr;
  static String get liveJoinButton => 'live.join_button'.tr;
  
  // 直播列表相关
  static String get liveSearchPlaceholder => 'live.search_placeholder'.tr;
  static String get liveUntitledStream => 'live.untitled_stream'.tr;
  static String get liveUnknownHost => 'live.unknown_host'.tr;
  static String get liveLoadingStreams => 'live.loading_streams'.tr;
  static String get liveNoStreamsFound => 'live.no_streams_found'.tr;
  static String get liveNoStreams => 'live.no_streams'.tr;
  static String liveSearchResults(int count) => sprintf('live.search_results'.tr, [count]);
  static String get liveTryDifferentKeywords => 'live.try_different_keywords'.tr;
  static String get liveCreateOrJoinHint => 'live.create_or_join_hint'.tr;
  static String get liveLoadMore => 'live.load_more'.tr;
  static String get livePullToLoadMore => 'live.pull_to_load_more'.tr;
  static String get liveAllLoaded => 'live.all_loaded'.tr;
  static String get liveViewers => 'live.viewers'.tr;
  
  // 直播房间退出相关
  static String get liveHostAppExit => 'live.host_app_exit'.tr;
  static String get liveDisconnectRoom => 'live.disconnect_room'.tr;
  static String get liveExitRoom => 'live.exit_room'.tr;
  static String get liveDeviceMuted => 'live.device_muted'.tr;
  static String get liveAppBackground => 'live.app_background'.tr;
  static String get liveAppTerminated => 'live.app_terminated'.tr;
  static String get liveRoomForcedExit => 'live.room_forced_exit'.tr;
  static String get liveConnectionDisconnected => 'live.connection_disconnected'.tr;
  static String get transfer => 'transfer'.tr;
  static String get transferPotePlaceholder => 'transferPotePlaceholder'.tr;
  static String get confirmTransfer => 'confirmTransfer'.tr;
  static String get transferTo => 'transferTo'.tr;
  static String get theRecipient => 'theRecipient'.tr;
  static String get transferAmountToast => 'transferAmountToast'.tr;
  static String get transferAmountVaildToast => 'transferAmountVaildToast'.tr;
  static String get transferAmountLimitVaildToast => 'transferAmountLimitVaildToast'.tr;
  static String get processing => 'processing'.tr;
  static String get verifyIdentityTransfer => 'verifyIdentityTransfer'.tr;
  static String get enterPaymentPassword => 'enterPaymentPassword'.tr;
  static String get verificationFailedMsg => 'verificationFailedMsg'.tr;
  static String get transferSuccessful => 'transferSuccessful'.tr;
  static String get transferSent => 'transferSent'.tr;
  static String get transferFailedAndTryAgain => 'transferFailedAndTryAgain'.tr;
  static String get transferFailed => 'transferFailed'.tr;
  static String get expired => 'expired'.tr;
  static String get waitingForRecipient => 'waitingForRecipient'.tr;
  static String get pendingPayment => 'pendingPayment'.tr;
  static String get completed => 'completed'.tr;
  static String get refunded => 'refunded'.tr;
  static String get transferDetails => 'transferDetails'.tr;
  static String get transferID => 'transferID'.tr;
  static String get transferStatus => 'transferStatus'.tr;
  static String get transferTime => 'transferTime'.tr;
  static String get recipient => 'recipient'.tr;
  static String get sender => 'sender'.tr;
  static String get note => 'note'.tr;
  static String get receivePayment => 'receivePayment'.tr;
  static String get paymentFailed => 'paymentFailed'.tr;
  static String get paymentSuccessful => 'paymentSuccessful'.tr;
  static String get amountCredited => 'amountCredited'.tr;
  static String get reminderStr => 'reminderStr'.tr;
  static String get identicalAmount => 'identicalAmount'.tr;
  static String get randomAmount => 'randomAmount'.tr;
  static String get exclusive => 'exclusive'.tr;
  static String get amountEach => 'amountEach'.tr;
  static String get totalAmount => 'totalAmount'.tr;
  static String get amount => 'amount'.tr;
  static String get sendTo => 'sendTo'.tr;
  static String get redPacketQuantity => 'redPacketQuantity'.tr;
  static String get redPacketEnterNumber => 'redPacketEnterNumber'.tr;
  static String get redPacketHitStr => 'redPacketHitStr'.tr;
  static String get prepareRedPacket => 'prepareRedPacket'.tr;
  static String get redPacketGroupNumber => 'redPacketGroupNumber'.tr;
  static String get sending => 'sending'.tr;
  static String get notEntered => 'notEntered'.tr;
  static String get redPacketAmountVail => 'redPacketAmountVail'.tr;
  static String get toBeClaimed => 'toBeClaimed'.tr;
  static String get claimed => 'claimed'.tr;
  static String get open => 'open'.tr;
  static String get formRedPacket => 'formRedPacket'.tr;
  static String get transferredToWallet => 'transferredToWallet'.tr;
  static String get redPacketSendInfo => 'redPacketSendInfo'.tr;
  static String get waitingToBeClaimed => 'waitingToBeClaimed'.tr;
  static String get noClaim => 'noClaim'.tr;
  static String get claimSuccessful => 'claimSuccessful'.tr;
  static String get claimFailed => 'claimFailed'.tr;
  static String get received => 'received'.tr;
  static String get redPacket => 'redPacket'.tr;
  static String get rPBMsg => 'rPBMsg'.tr;
  static String get transferExpense => 'transferExpense'.tr;
  static String get transferRefund => 'transferRefund'.tr;
  static String get transferReceipt => 'transferReceipt'.tr;
  static String get orgTransferReceipt => 'orgTransferReceipt'.tr;
  static String get redPacketRefund => 'redPacketRefund'.tr;
  static String get redPacketExpense => 'redPacketExpense'.tr;
  static String get redPacketReceipt => 'redPacketReceipt'.tr;
  static String get recharge  => 'recharge'.tr;
  static String get withdraw => 'withdraw'.tr;
  static String get consumption => 'consumption'.tr;
  static String get unknownType => 'unknownType'.tr;
  static String get enterTopUpAmount => 'enterTopUpAmount'.tr;
  static String get topUpSuccessful => 'topUpSuccessful'.tr;
  static String get topUpFailed => 'topUpFailed'.tr;

  static String get screenSharePermissionDenied => 'screenSharePermissionDenied'.tr;
  static String get deviceNotSupported => 'deviceNotSupported'.tr;
  static String get currency => 'currency'.tr;
  static String get selectType => 'selectType'.tr;
  static String get selectCurrency => 'selectCurrency'.tr;

    
  // 红包相关
  static String get viewDetails => 'wallet.viewDetails'.tr;
  static String get redPacketFull => 'wallet.redPacketFull'.tr;
  static String get redPacketInvalid => 'wallet.redPacketInvalid'.tr;
  static String get redPacketExpired => 'wallet.redPacketExpired'.tr;
  static String get redPacketRetry => 'wallet.redPacketRetry'.tr;
  static String get alreadyReceived => 'errCode.alreadyReceived'.tr;

  static String get walletTitle => 'wallet.title'.tr;
  static String get walletActivate => 'wallet.activate'.tr;
  static String get toCreateWallet => 'toCreateWallet'.tr;
  static String get walletBalance => 'wallet.balance'.tr;
  static String get walletRecharge => 'wallet.recharge'.tr;
  static String get walletWithdraw => 'wallet.withdraw'.tr;
  static String get walletExchange => 'wallet.exchange'.tr;
  static String get walletDetails => 'wallet.details'.tr;
  static String get walletBill => 'wallet.bill'.tr;
  static String get walletBillDetail => 'wallet.billDetail'.tr;
  static String get walletBillType => 'wallet.billType'.tr;
  static String get walletBillTime => 'wallet.billTime'.tr;
  static String get walletBillAmount => 'wallet.billAmount'.tr;
  static String get walletBillStatus => 'wallet.billStatus'.tr;
  static String get walletBillOrderNo => 'wallet.billOrderNo'.tr;
  static String get walletBillCounterparty => 'wallet.billCounterparty'.tr;
  static String get walletBillRemark => 'wallet.billRemark'.tr;
  static String get walletCopied => 'wallet.copied'.tr;
  static String get walletAllTypes => 'wallet.allTypes'.tr;
  static String get walletAllTime => 'wallet.allTime'.tr;
  static String get walletTransfer => 'wallet.transfer'.tr;
  static String get walletTransferAmount => 'wallet.transferAmount'.tr;
  static String get walletTransferDescription => 'wallet.transferDescription'.tr;
  static String get walletRedPacket => 'wallet.redPacket'.tr;
  static String get walletReceipt => 'wallet.receipt'.tr;
  static String get walletWithdrawal => 'wallet.withdrawal'.tr;
  static String get walletLastWeek => 'wallet.lastWeek'.tr;
  static String get walletLastMonth => 'wallet.lastMonth'.tr;
  static String get walletLastThreeMonths => 'wallet.lastThreeMonths'.tr;
  static String get walletNoMoreData => 'wallet.noMoreData'.tr;
  static String get walletVerifyPassword => 'wallet.verifyPassword'.tr;
  static String get walletEnterPassword => 'wallet.enterPassword'.tr;
  static String get walletVerifyIdentity => 'wallet.verifyIdentity'.tr;
  static String get walletSetTransactionPassword => 'wallet.setTransactionPassword'.tr;
  static String get walletEnterTransactionPassword => 'wallet.enterTransactionPassword'.tr;
  static String get walletConfirmTransactionPassword => 'wallet.confirmTransactionPassword'.tr;
  static String get walletPasswordMismatch => 'wallet.passwordMismatch'.tr;
  static String get walletPasswordLength => 'wallet.passwordLength'.tr;
  static String get walletCancel => 'wallet.cancel'.tr;
  static String get walletConfirm => 'wallet.confirm'.tr;
  static String get walletSuccess => 'wallet.success'.tr;
  static String get walletFailed => 'wallet.failed'.tr;
  static String get walletProcessing => 'wallet.processing'.tr;
  static String get walletActivated => 'wallet.walletActivated'.tr;
  static String get walletVerifyFailed => 'wallet.verifyFailed'.tr;
  static String get walletSetFailed => 'wallet.setFailed'.tr;
  static String get walletEnterAmount => 'wallet.enterAmount'.tr;
  static String get walletAmountInvalid => 'wallet.amountInvalid'.tr;
  static String get walletInsufficientBalance => 'wallet.insufficientBalance'.tr;
  static String get walletOperationSuccess => 'wallet.operationSuccess'.tr;
  static String get walletOperationFailed => 'wallet.operationFailed'.tr;
  static String get walletVerifyLoginPassword => 'wallet.verifyLoginPassword'.tr;
  static String get walletActivateSuccess => 'wallet.activateSuccess'.tr;
  static String get walletActivateSuccessDesc => 'wallet.activateSuccessDesc'.tr;
  static String get walletActivateNotice => 'wallet.activateNotice'.tr;
  static String get walletCompensationBalance => 'wallet.compensationBalance'.tr;
  static String get compensationRecords => 'wallet.compensationRecords'.tr;
  static String get compensationInitial => 'wallet.compensationInitial'.tr;
  static String get compensationDeduction => 'wallet.compensationDeduction'.tr;
  static String get compensationAdjustment => 'wallet.compensationAdjustment'.tr;
  static String get noRecord => 'wallet.noRecord'.tr;
  static String get unknown => 'common.unknown'.tr;
  static String get walletRechargeDeveloping => 'wallet.rechargeDeveloping'.tr;
  static String get walletWithdrawDeveloping => 'wallet.withdrawDeveloping'.tr;
  static String get walletTransactionRecord => 'wallet.transactionRecord'.tr;
  static String get walletViewAll => 'wallet.viewAll'.tr;
  static String get walletVerifyIdentityForModify => 'wallet.verifyIdentityForModify'.tr;
  static String get walletVerifyIdentityForSet => 'wallet.verifyIdentityForSet'.tr;
  static String get walletModifyPasswordSuccess => 'wallet.modifyPasswordSuccess'.tr;
  static String get walletSetPasswordSuccess => 'wallet.setPasswordSuccess'.tr;
  static String get totalAssetsConverted => 'wallet.totalAssetsConverted'.tr;
  static String get exchangeRate => 'wallet.exchangeRate'.tr;
  static String get selectTime => 'wallet.selectTime'.tr;

  static String get walletActivateFailed => 'common.walletActivateFailed'.tr;
  static String get selectEmoji => 'selectEmoji'.tr;
  static String get refundNotification => 'refundNotification'.tr;
  static String get refundAmount => 'refundAmount'.tr;
  static String get refundType => 'refundType'.tr;
  static String get refundMethod => 'refundMethod'.tr;
  static String get returnedToWallet => 'returnedToWallet'.tr;
  static String get timeCredited => 'timeCredited'.tr;

  static String get deleteChatWarning => 'deleteChatWarning'.tr;

  static String get needPhotoPermission => 'needPhotoPermission'.tr;
  static  String get needPhotoFullAccess => 'permission.needPhotoFullAccess'.tr;
  static  String get needCameraPermission => 'permission.needCameraPermission'.tr;
  static  String get needPhotoFullAccessTitle => 'permission.needPhotoFullAccessTitle'.tr;
  static  String get needPhotoFullAccessDesc => 'permission.needPhotoFullAccessDesc'.tr;
  static  String get needMorePhotosAccess => 'needMorePhotosAccess'.tr;
  static  String get needMorePhotosAccessDesc => 'needMorePhotosAccessDesc'.tr;
  static  String get goToSettings => 'permission.goToSettings'.tr;

  static String get noOrg => 'noOrg'.tr;
  static String get joinInvitationSuccess => 'joinInvitationSuccess'.tr;
  static String get unknownOrg => 'unknownOrg'.tr;
  static String get selectOrg => 'selectOrg'.tr;

  static String get amountExceedMax => 'amountExceedMax'.tr;
  static String get balanceExceeded => 'balanceExceeded'.tr;
  static String get exceedGroupMemberLimit => 'exceedGroupMemberLimit'.tr; 
  static String get invalidAmount => 'invalidAmount'.tr;

  static String get addAcountTitle => 'addAcountTitle'.tr;
  static String get avaterchangeAction => 'avaterchangeAction'.tr;
  static String get invitationInputPrompt => 'invitationInputPrompt'.tr;
  static String get redPacketPassword => 'redPacketPassword'.tr;
  static String get redPacketCommandContent => 'redPacketCommandContent'.tr;
  static String get enterCommandToClaim => 'enterCommandToClaim'.tr;
  static String get enterPasswordPrompt => 'enterPasswordPrompt'.tr;
  static String get redPacketForRecipient => 'redPacketForRecipient'.tr;
  static String get onlyRecipientCanClaim => 'onlyRecipientCanClaim'.tr;
  static String get redPacketSentByUser => 'redPacketSentByUser'.tr;
  static String get passwordIncorrect => 'passwordIncorrect'.tr;
  static String get receiverNotInOrganization => 'receiverNotInOrganization'.tr;
  static String get userNotInSameOrganization => 'userNotInSameOrganization'.tr;
  static String get cannotReceiveOwnTransfer => 'cannotReceiveOwnTransfer'.tr;
  static String get receiverNotTargetUser => 'receiverNotTargetUser'.tr;
  static String get orgTransferReceiverMustBeAdmin => 'orgTransferReceiverMustBeAdmin'.tr;
  static String get receiverNotExclusiveReceiver => 'receiverNotExclusiveReceiver'.tr;
  static String get unknownTransactionType => 'unknownTransactionType'.tr;
  static String get incorrectPassword => 'incorrectPassword'.tr;
  static String get passwordCannotBeEmpty => 'passwordCannotBeEmpty'.tr;
  static String get editInfo => 'editInfo'.tr;
  static String get pleaseEnterNewInfo => 'pleaseEnterNewInfo'.tr;
  static String get pleaseEnterContent => 'pleaseEnterContent'.tr;
  static String get emailVerification => 'emailVerification'.tr;
  static String get featureInDevelopment => 'featureInDevelopment'.tr;
  static String get captchaError => 'errCode.captchaError'.tr;
  static String get deviceRegisterNumExceed => 'errCode.deviceRegisterNumExceed'.tr;
  static String get emailInUse => 'errCode.emailInUse'.tr;
  static String get invalidInvitationCode => 'errCode.invalidInvitationCode'.tr;  static String get captchaRefreshPrompt => 'captchaRefreshPrompt'.tr;
    // 签到页面
  static String get checkin => 'checkin'.tr;
  static String get checkinReward => 'checkinReward'.tr;
  static String get dailyCheckinReward => 'dailyCheckinReward'.tr;
  static String get myRewards => 'myRewards'.tr;
  static String get consecutiveCheckin => 'consecutiveCheckin'.tr;
  static String get remindMeTomorrow => 'remindMeTomorrow'.tr;
  static String get congratulationsCheckinSuccess => 'congratulationsCheckinSuccess'.tr;
  static String get complete => 'complete'.tr;
  static String get checkinFailed => 'checkinFailed'.tr;
  static String get checkinNetworkError => 'checkinNetworkError'.tr;
  static String get permissionDenied => 'permissionDenied'.tr;
  static String get calendarPermissionRequired => 'calendarPermissionRequired'.tr;
  static String get calendarAddFailed => 'calendarAddFailed'.tr;
  static String get cannotGetCalendar => 'cannotGetCalendar'.tr;
  static String get calendarAddSuccessfully => 'calendarAddSuccessfully'.tr;
  static String get checkinReminderAdded => 'checkinReminderAdded'.tr;
  static String get cannotCreateCalendarEvent => 'cannotCreateCalendarEvent'.tr;
  static String get calendarReminderError => 'calendarReminderError'.tr;
  static String get dailyCheckinReminder => 'dailyCheckinReminder'.tr;
  static String get checkinReminderDescription => 'checkinReminderDescription'.tr;

  // 签到规则说明
  static String get checkinRuleDescription => 'checkinRuleDescription'.tr;
  static String get viewMore => 'viewMore'.tr;
  static String get viewFull => 'viewFull'.tr;
  static String get noData => 'noData'.tr;
  static String get loadFailed => 'loadFailed'.tr;
  static String get retry => 'retry'.tr;
  static String get takePhoto => 'takePhoto'.tr;
  static String get fromAlbum => 'fromAlbum'.tr;
  // 奖励相关
  static String get cashReward => 'cashReward'.tr;
  static String get lotteryReward => 'lotteryReward'.tr;
  static String get pointReward => 'pointReward'.tr;
  static String get otherReward => 'otherReward'.tr;
  static String get rewardApplied => 'rewardApplied'.tr;
  static String get rewardPending => 'rewardPending'.tr;
  static String get noCheckinRewards => 'noCheckinRewards'.tr;
  static String get goCheckinToGetRewards => 'goCheckinToGetRewards'.tr;
  static String get loadMoreRewards => 'loadMoreRewards'.tr;
  static String get loading => 'loading'.tr;
  static String get lotteryTicket => 'lotteryTicket'.tr;
  static String get points => 'points'.tr;
  static String rewardReceived(String rewardType, String amount, String currency) => 
      sprintf('rewardReceived'.tr, [rewardType, amount, currency]);
  static String gotTicket(String ticketName, String amount) => 
      sprintf('gotTicket'.tr, [ticketName, amount]);
  static String gotReward(String reward) => 
      sprintf('gotReward'.tr, [reward]);
  
  // 文件预览相关
  static String get processingFile => 'processingFile'.tr;
  static String get fileDownloading => 'fileDownloading'.tr;
  static String get downloadFailed => 'downloadFailed'.tr;
  static String get cannotGetFile => 'cannotGetFile'.tr;
  static String get noAppToOpenFile => 'noAppToOpenFile'.tr;
  static String get noPermissionToAccessFile => 'noPermissionToAccessFile'.tr;
  static String get fileNotExistOrDeleted => 'fileNotExistOrDeleted'.tr;
  static String get openFileFailed => 'openFileFailed'.tr;
  static String get processingFailed => 'processingFailed'.tr;
  static String downloadingProgress(int percent) => 
      sprintf('downloadingProgress'.tr, [percent]);

  static String get myTickets => 'myTickets'.tr;
  static String get noTickets => 'noTickets'.tr;
  static String get participateToGetTickets => 'participateToGetTickets'.tr;

  // Lottery tickets related
  static String get useNow => 'useNow'.tr;
  static String get loadingMore => 'loadingMore'.tr;
  static String get used => 'used'.tr;
  static String get daysUntilExpiry => 'daysUntilExpiry'.tr;
  static String get cannotUse => 'cannotUse'.tr;
  static String get ticketExpiredOrUsed => 'ticketExpiredOrUsed'.tr;
  static String get loadFailedPrefix => 'loadFailedPrefix'.tr;
  static String get unknownTicket => 'unknownTicket'.tr;
  static String get lotteryActivity => 'lotteryActivity'.tr;
  static String get loadTicketsFailed => 'loadTicketsFailed'.tr;
  
  // Prize records related
  static String get prizeRecords => 'prizeRecords'.tr;
  static String get all => 'all'.tr;
  static String get delivered => 'delivered'.tr;
  static String get pending => 'pending'.tr;
  static String get cash => 'cash'.tr;
  static String get virtual => 'virtual'.tr;
  static String get physical => 'physical'.tr;
  static String get unknownPrize => 'unknownPrize'.tr;
  static String get loadFailedRetry => 'loadFailedRetry'.tr;
  static String get noPrizeRecords => 'noPrizeRecords'.tr;
  static String get participateToWinPrizes => 'participateToWinPrizes'.tr;

  // 聊天相关的国际化字符串
  static String get imageSizeLimit => 'imageSizeLimit'.tr;
  static String get videoSizeLimit => 'videoSizeLimit'.tr;
  static String get fileSizeLimit => 'fileSizeLimit'.tr;
  static String get sendingFile => 'sendingFile'.tr;
  static String get sendFileSuccess => 'sendFileSuccess'.tr;
  static String get sendFileFailed => 'sendFileFailed'.tr;
  static String get selectFileFailed => 'selectFileFailed'.tr;
  static String get sent => 'sent'.tr;
  static String get revokeFailed => 'revokeFailed'.tr;
  static String get joinMeetingContent => 'joinMeetingContent'.tr;
  static String get joinMeetingFailed => 'joinMeetingFailed'.tr;
  
  // 发现页面相关字符串
  static String get dailyCheckinGetReward => 'dailyCheckinGetReward'.tr;
  static String get videoConferenceFunction => 'videoConferenceFunction'.tr;
  static String get myTicketsDesc => 'myTicketsDesc'.tr;
  static String get winningRecords => 'winningRecords'.tr;

  static String get forgetPasswordContactService => 'forgetPasswordContactService'.tr;
  static String get phoneRegisterHint => 'phoneRegisterHint'.tr;
  static String get updateTime => 'updateTime'.tr;

  // 轮盘抽奖相关
  static String get luckWheel => 'luckWheel'.tr;
  static String get spinToWin => 'spinToWin'.tr;
  static String get startLottery => 'startLottery'.tr;
  static String get spinning => 'spinning'.tr;
  static String get congratulations => 'congratulations'.tr;
  static String get thankYou => 'thankYou'.tr;
  static String get noLuck => 'noLuck'.tr;
  static String get tryNextTime => 'tryNextTime'.tr;
  static String get prizeWon => 'prizeWon'.tr;
  static String get ticketUsed => 'ticketUsed'.tr;
  static String get lotteryFailed => 'lotteryFailed'.tr;
  static String get getPrizesError => 'getPrizesError'.tr;
  static String get lotteryError => 'lotteryError'.tr;


static String get paymentMethod => 'paymentMethod'.tr;
static String get bankCard => 'bankCard'.tr;
static String get wechatPayment => 'wechatPayment'.tr;
static String get alipayPayment => 'alipayPayment'.tr;
static String get addPaymentMethod => 'addPaymentMethod'.tr;
static String get addBankCard => 'addBankCard'.tr;
static String get addQRCode => 'addQRCode'.tr;
static String get bankName => 'bankName'.tr;
static String get cardNo => 'cardNo'.tr;
static String get cardNumber => 'cardNumber'.tr;
static String get branchName => 'branchName'.tr;
static String get accountHolder => 'accountHolder'.tr;
static String get accountHolderName => 'accountHolderName'.tr;

static String get qrCodeImage => 'qrCodeImage'.tr;
static String get uploadQRCode => 'uploadQRCode'.tr;
static String get defaulticon => 'defaulticon'.tr;
static String get setAsDefault => 'setAsDefault'.tr;
static String get defaultPayment => 'defaultPayment'.tr;
static String get clickToAddPaymentMethod => 'clickToAddPaymentMethod'.tr;
static String get noPaymentMethods => 'noPaymentMethods'.tr;
static String get deletePayment => 'deletePayment'.tr;
static String get confirmDeletePayment => 'confirmDeletePayment'.tr;
static String get inputBankName => 'inputBankName'.tr;
static String get inputCardNumber => 'inputCardNumber'.tr;
static String get inputBranchName => 'inputBranchName'.tr;
static String get inputHolderName => 'inputHolderName'.tr;
static String get inputAccountName => 'inputAccountName'.tr;
static String get setAsDefaultPayment => 'setAsDefaultPayment'.tr;
static String get fillInCompleteInfo => 'fillInCompleteInfo'.tr;
static String get confirmAdd => 'confirmAdd'.tr;
static String get wechat => 'wechat'.tr;
static String get alipay => 'alipay'.tr;
static String get clickToUploadQRCode => 'clickToUploadQRCode'.tr;
static String get uploadQRCodeImage => 'uploadQRCodeImage'.tr;
static String get deleteSuccess => 'deleteSuccess'.tr;
static String get deleteFailed => 'deleteFailed'.tr;
static String get identityVerify => 'identityVerify'.tr;
static String get verifyStatusPending => 'verifyStatus_pending'.tr;
static String get verifyStatusReviewing => 'verifyStatus_reviewing'.tr;
static String get verifyStatusApproved => 'verifyStatus_approved'.tr;
static String get verifyStatusRejected => 'verifyStatus_rejected'.tr;
static String get realName => 'realName'.tr;
static String get idCardNumber => 'idCardNumber'.tr;
static String get idCardFront => 'idCardFront'.tr;
static String get idCardBack => 'idCardBack'.tr;
static String get uploadFrontHint => 'uploadFrontHint'.tr;
static String get uploadBackHint => 'uploadBackHint'.tr;
static String get verifyTipsTitle => 'verifyTipsTitle'.tr;
static String get verifyTipsContent => 'verifyTipsContent'.tr;
static String get submitVerify => 'submitVerify'.tr;
static String get verifyInfo => 'verifyInfo'.tr;
static String get verifyTime => 'verifyTime'.tr;
static String get verifyStatus => 'verifyStatus'.tr;
static String get clickToUpload => 'clickToUpload'.tr;
static String get verifySuccess => 'verifySuccess'.tr;
static String get verifyFailed => 'verifyFailed'.tr;
static String get pleaseEnterRealName => 'pleaseEnterRealName'.tr;
static String get pleaseEnterIdCard => 'pleaseEnterIdCard'.tr;
static String get pleaseUploadFront => 'pleaseUploadFront'.tr;
static String get pleaseUploadBack => 'pleaseUploadBack'.tr;
static String get submitSuccess => 'submitSuccess'.tr;
static String get submitSuccessMsg => 'submitSuccessMsg'.tr;
static String get submitFailed => 'submitFailed'.tr;
static String get reviewingStatus => 'reviewingStatus'.tr;
static String get reviewingMsg => 'reviewingMsg'.tr;
static String get withdrawal => 'withdrawal'.tr;
  static String get withdrawalAmount => 'withdrawalAmount'.tr;
  static String get enterAmount => 'enterAmount'.tr;
  static String get currentBalance => 'currentBalance'.tr;
  static String get withdrawalFee => 'withdrawalFee'.tr;
  static String get actualArrival => 'actualArrival'.tr;
  static String get withdrawalRules => 'withdrawalRules'.tr;
  static String get withdrawTo => 'withdrawTo'.tr;
  static String get addAccount => 'addAccount'.tr;
  static String get submitApplication => 'submitApplication'.tr;
  static String get inputPaymentPassword => 'inputPaymentPassword'.tr;
  static String get withdrawalSuccess => 'withdrawalSuccess'.tr;
  static String get orderNumber => 'orderNumber'.tr;
  static String get withdrawalRecord => 'withdrawalRecord'.tr;
  static String get withdrawalFailed => 'withdrawalFailed'.tr;
  static String get withdrawalRejected => 'withdrawalRejected'.tr;
  static String get contactCustomerService => 'contactCustomerService'.tr;
  static String get minWithdrawal => 'minWithdrawal'.tr;
  static String get maxWithdrawal => 'maxWithdrawal'.tr;
  static String get needRealName => 'needRealName'.tr;
  static String get needBindAccount => 'needBindAccount'.tr;
  static String get enter6DigitPassword => 'enter6DigitPassword'.tr;

  static String get submit => 'submit'.tr;

  static String get fee => 'fee'.tr;
  static String get actualAmount => 'actualAmount'.tr;
  static String get bank => 'bank'.tr;
  static String get branch => 'branch'.tr;
  static String get accountName => 'accountName'.tr;
  static String get accountNumber => 'accountNumber'.tr;
  static String get withdrawalLimit => 'withdrawalLimit'.tr;
  static String get singleTransaction => 'singleTransaction'.tr;
  static String get dailyLimit => 'dailyLimit'.tr;
  static String get processingTime => 'processingTime'.tr;
  static String get businessDays => 'businessDays'.tr;
  static String get withdrawalInstructions => 'withdrawalInstructions'.tr;
  static String get selectAccount => 'selectAccount'.tr;
  static String get createNewAccount => 'createNewAccount'.tr;
  static String get editAccount => 'editAccount'.tr;
  static String get deleteAccount => 'deleteAccount'.tr;
  static String get defaultAccount => 'defaultAccount'.tr;
  static String get withdrawalHistory => 'withdrawalHistory'.tr;
  static String get withdrawalDetails => 'withdrawalDetails'.tr;
  static String get applicationTime => 'applicationTime'.tr;
  static String get completionTime => 'completionTime'.tr;
  static String get remarks => 'remarks'.tr;
  static String get insufficientBalance => 'insufficientBalance'.tr;
  static String get exceedLimit => 'exceedLimit'.tr;
  static String get passwordError => 'passwordError'.tr;
  static String get tryAgain => 'tryAgain'.tr;
  static String get forgotPassword => 'forgotPassword'.tr;
  static String get resetPassword => 'resetPassword'.tr;
  static String get securityVerification => 'securityVerification'.tr;
  static String get sendCode => 'sendCode'.tr;
  static String get resend => 'resend'.tr;
  static String get s => 's'.tr;
  static String get tips => 'tips'.tr;


}
