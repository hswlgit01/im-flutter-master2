import 'package:get/get.dart';
import 'package:openim/pages/account_register/account_register_binding.dart';
import 'package:openim/pages/account_register/account_register_view.dart';
import 'package:openim/pages/add_acount_page/add_acount_binding.dart';
import 'package:openim/pages/add_acount_page/add_acount_view.dart';
import 'package:openim/pages/article/article_binding.dart';
import 'package:openim/pages/article/article_view.dart';
import 'package:openim/pages/chat/chat_search/chat_search_file/chat_search_file_binding.dart';
import 'package:openim/pages/chat/chat_search/chat_search_file/chat_search_file_view.dart';
import 'package:openim/pages/chat/chat_search/chat_search_image/chat_search_image_binding.dart';
import 'package:openim/pages/chat/chat_search/chat_search_image/chat_search_image_view.dart';
import 'package:openim/pages/chat/chat_search/chat_search_text/chat_search_text_binding.dart';
import 'package:openim/pages/chat/chat_search/chat_search_text/chat_search_text_view.dart';
import 'package:openim/pages/chat/chat_search/chat_search_video/chat_search_video_binding.dart';
import 'package:openim/pages/chat/chat_search/chat_search_video/chat_search_video_view.dart';
import 'package:openim/pages/chat/group_setup/group_ac/binding.dart';
import 'package:openim/pages/chat/group_setup/group_ac/view.dart';
import 'package:openim/pages/chat_notification/binding.dart';
import 'package:openim/pages/chat_notification/view.dart';
import 'package:openim/pages/checkin_rewards/checkin_rewards_binding.dart';
import 'package:openim/pages/checkin_rewards/checkin_rewards_view.dart';
// 移除签到规则说明页面导入
import 'package:openim/pages/article/article_binding.dart';
import 'package:openim/pages/article/article_view.dart';
import 'package:openim/pages/lottery_tickets/lottery_wheel_binding.dart';
import 'package:openim/pages/lottery_tickets/lottery_wheel_view.dart';
import 'package:openim/pages/contacts/user_profile_panel/mute_setup/binding.dart';
import 'package:openim/pages/contacts/user_profile_panel/mute_setup/view.dart';
import 'package:openim/pages/lottery_tickets/lottery_tickets_binding.dart';
import 'package:openim/pages/lottery_tickets/lottery_tickets_view.dart';
import 'package:openim/pages/mine/edit_my_info/edit_my_info_binding.dart';
import 'package:openim/pages/mine/edit_my_info/edit_my_info_view.dart';
import 'package:openim/pages/mine/my_qrcode/binding.dart';
import 'package:openim/pages/mine/my_qrcode/view.dart';
import 'package:openim/pages/mine/my_team/my_team_binding.dart';
import 'package:openim/pages/mine/my_team/my_team_view.dart';
import 'package:openim/pages/prize_records/prize_records_binding.dart';
import 'package:openim/pages/prize_records/prize_records_view.dart';
import 'package:openim/pages/search/binding.dart';
import 'package:openim/pages/search/view.dart';
import 'package:openim/pages/checkin/checkin_binding.dart';
import 'package:openim/pages/checkin/checkin_view.dart';
import 'package:openim/pages/web_view/binding.dart';
import 'package:openim/pages/web_view/view.dart';

import '../pages/chat/chat_binding.dart';
import '../pages/chat/chat_setup/chat_setup_binding.dart';
import '../pages/chat/chat_setup/chat_setup_view.dart';
import '../pages/chat/chat_view.dart';
import '../pages/chat/group_setup/edit_name/edit_name_binding.dart';
import '../pages/chat/group_setup/edit_name/edit_name_view.dart';
import '../pages/chat/group_setup/group_manage/group_manage_binding.dart';
import '../pages/chat/group_setup/group_manage/group_manage_view.dart';
import '../pages/chat/group_setup/group_member_list/group_member_list_binding.dart';
import '../pages/chat/group_setup/group_member_list/group_member_list_view.dart';
import '../pages/chat/group_setup/group_qrcode/group_qrcode_binding.dart';
import '../pages/chat/group_setup/group_qrcode/group_qrcode_view.dart';
import '../pages/chat/group_setup/group_setup_binding.dart';
import '../pages/chat/group_setup/group_setup_view.dart';
import '../pages/contacts/add_by_search/add_by_search_binding.dart';
import '../pages/contacts/add_by_search/add_by_search_view.dart';
import '../pages/contacts/add_method/add_method_binding.dart';
import '../pages/contacts/add_method/add_method_view.dart';
import '../pages/contacts/create_group/create_group_binding.dart';
import '../pages/contacts/create_group/create_group_view.dart';
import '../pages/contacts/friend_list/friend_list_binding.dart';
import '../pages/contacts/friend_list/friend_list_view.dart';
import '../pages/contacts/friend_requests/friend_requests_binding.dart';
import '../pages/contacts/friend_requests/friend_requests_view.dart';
import '../pages/contacts/friend_requests/process_friend_requests/process_friend_requests_binding.dart';
import '../pages/contacts/friend_requests/process_friend_requests/process_friend_requests_view.dart';
import '../pages/contacts/group_list/group_list_binding.dart';
import '../pages/contacts/group_list/group_list_view.dart';
import '../pages/contacts/group_profile_panel/group_profile_panel_binding.dart';
import '../pages/contacts/group_profile_panel/group_profile_panel_view.dart';
import '../pages/contacts/group_requests/group_requests_binding.dart';
import '../pages/contacts/group_requests/group_requests_view.dart';
import '../pages/contacts/group_requests/process_group_requests/process_group_requests_binding.dart';
import '../pages/contacts/group_requests/process_group_requests/process_group_requests_view.dart';
import '../pages/contacts/select_contacts/friend_list/friend_list_binding.dart';
import '../pages/contacts/select_contacts/friend_list/friend_list_view.dart';
import '../pages/contacts/select_contacts/group_list/group_list_binding.dart';
import '../pages/contacts/select_contacts/group_list/group_list_view.dart';
import '../pages/contacts/select_contacts/search_contacts/search_contacts_binding.dart';
import '../pages/contacts/select_contacts/search_contacts/search_contacts_view.dart';
import '../pages/contacts/select_contacts/select_contacts_binding.dart';
import '../pages/contacts/select_contacts/select_contacts_view.dart';
import '../pages/contacts/send_verification_application/send_verification_application_binding.dart';
import '../pages/contacts/send_verification_application/send_verification_application_view.dart';
import '../pages/contacts/user_profile_panel/friend_setup/friend_setup_binding.dart';
import '../pages/contacts/user_profile_panel/friend_setup/friend_setup_view.dart';
import '../pages/contacts/user_profile_panel/personal_info/personal_info_binding.dart';
import '../pages/contacts/user_profile_panel/personal_info/personal_info_view.dart';
import '../pages/contacts/user_profile_panel/set_remark/set_remark_binding.dart';
import '../pages/contacts/user_profile_panel/set_remark/set_remark_view.dart';
import '../pages/contacts/user_profile_panel/user_profile _panel_binding.dart';
import '../pages/contacts/user_profile_panel/user_profile _panel_view.dart';
import '../pages/forget_password/forget_password_binding.dart';
import '../pages/forget_password/forget_password_view.dart';
import '../pages/forget_password/reset_password/reset_password_binding.dart';
import '../pages/forget_password/reset_password/reset_password_view.dart';
import '../pages/global_search/global_search_binding.dart';
import '../pages/global_search/global_search_view.dart';
import '../pages/home/home_binding.dart';
import '../pages/home/home_view.dart';
import '../pages/login/login_binding.dart';
import '../pages/login/login_view.dart';
import '../pages/luck_money/group_member_list/group_member_list_binding.dart';
import '../pages/luck_money/group_member_list/group_member_list_view.dart';
import '../pages/luck_money/luck_money.dart';
import '../pages/luck_money/luck_money_binding.dart';
import '../pages/luck_money/luck_money_detail/luck_money_detail_binding.dart';
import '../pages/luck_money/luck_money_detail/luck_money_detail_view.dart';
import '../pages/luck_money/luck_money_log/luck_money_log_binding.dart';
import '../pages/luck_money/luck_money_log/luck_money_log_view.dart';
import '../pages/mine/about_us/about_us_binding.dart';
import '../pages/mine/about_us/about_us_view.dart';
import '../pages/mine/payment_method/payment_method_binding.dart';
import '../pages/mine/payment_method/payment_method_view.dart';
import '../pages/mine/account_setup/account_setup_binding.dart';
import '../pages/mine/account_setup/account_setup_view.dart';
import '../pages/mine/blacklist/blacklist_binding.dart';
import '../pages/mine/blacklist/blacklist_view.dart';
import '../pages/mine/language_setup/language_setup_binding.dart';
import '../pages/mine/language_setup/language_setup_view.dart';
import '../pages/mine/my_info/my_info_binding.dart';
import '../pages/mine/my_info/my_info_view.dart';
import '../pages/register/register_binding.dart';
import '../pages/register/register_view.dart';
import '../pages/register/set_password/set_password_binding.dart';
import '../pages/register/set_password/set_password_view.dart';
import '../pages/register/set_self_info/set_self_info_binding.dart';
import '../pages/register/set_self_info/set_self_info_view.dart';
import '../pages/register/verify_phone/verify_phone_binding.dart';
import '../pages/register/verify_phone/verify_phone_view.dart';
import '../pages/splash/splash_binding.dart';
import '../pages/splash/splash_view.dart';
import '../pages/wallet/bill/bill_detail/bill_detail_logic.dart';
import '../pages/wallet/bill/bill_detail/bill_detail_view.dart';
import '../pages/wallet/transfer/transfer_logic.dart';
import '../pages/wallet/transfer/transfer_view.dart';
import '../pages/wallet/wallet_logic.dart';
import '../pages/wallet/wallet_view.dart';

// import '../pages/wallet/bill/bill_detail/bill_detail_logic.dart';
// import '../pages/wallet/bill/bill_detail/bill_detail_view.dart';
// import '../pages/wallet/transfer/transfer_logic.dart';
// import '../pages/wallet/transfer/transfer_view.dart';
// import '../pages/wallet/wallet_logic.dart';
// import '../pages/wallet/wallet_view.dart';

// import '../pages/wallet/bill/bill_detail/bill_detail_logic.dart';
// import '../pages/wallet/bill/bill_detail/bill_detail_view.dart';
// import '../pages/wallet/transfer/transfer_logic.dart';
// import '../pages/wallet/transfer/transfer_view.dart';
// import '../pages/wallet/wallet_logic.dart';
// import '../pages/wallet/wallet_view.dart';

part 'app_routes.dart';

class AppPages {
  static _pageBuilder({
    required String name,
    required GetPageBuilder page,
    Bindings? binding,
    bool preventDuplicates = true,
    bool popGesture = true,
  }) =>
      GetPage(
        name: name,
        page: page,
        binding: binding,
        preventDuplicates: preventDuplicates,
        transition: Transition.cupertino,
        popGesture: popGesture,
      );

  static final routes = <GetPage>[
    _pageBuilder(
      name: AppRoutes.splash,
      page: () => SplashPage(),
      binding: SplashBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.login,
      page: () => LoginPage(),
      binding: LoginBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.home,
      page: () => HomePage(),
      binding: HomeBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.chat,
      page: () => ChatPage(),
      binding: ChatBinding(),
      preventDuplicates: false,
    ),
    _pageBuilder(
        name: AppRoutes.chatNotification,
        page: () => ChatNotificationPage(),
        binding: ChatNotificationBinding()),
    _pageBuilder(
      name: AppRoutes.chatSetup,
      page: () => ChatSetupPage(),
      binding: ChatSetupBinding(),
      popGesture: false,
    ),
    _pageBuilder(
      name: AppRoutes.chatSearchText,
      page: () => ChatSearchTextPage(),
      binding: ChatSearchTextBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.chatSearchImage,
      page: () => ChatSearchImagePage(),
      binding: ChatSearchImageBinding(),
    ),

    _pageBuilder(
      name: AppRoutes.chatSearchVideo,
      page: () => ChatSearchVideoPage(),
      binding: ChatSearchVideoBinding(),
    ),

    _pageBuilder(
      name: AppRoutes.chatSearchFile,
      page: () => ChatSearchFilePage(),
      binding: ChatSearchFileBinding(),
    ),

    _pageBuilder(
      name: AppRoutes.addContactsMethod,
      page: () => AddContactsMethodPage(),
      binding: AddContactsMethodBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.addContactsBySearch,
      page: () => AddContactsBySearchPage(),
      binding: AddContactsBySearchBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.userProfilePanel,
      page: () => UserProfilePanelPage(),
      binding: UserProfilePanelBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.personalInfo,
      page: () => PersonalInfoPage(),
      binding: PersonalInfoBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.friendSetup,
      page: () => FriendSetupPage(),
      binding: FriendSetupBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.setFriendRemark,
      page: () => SetFriendRemarkPage(),
      binding: SetFriendRemarkBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.sendVerificationApplication,
      page: () => SendVerificationApplicationPage(),
      binding: SendVerificationApplicationBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.groupProfilePanel,
      page: () => GroupProfilePanelPage(),
      binding: GroupProfilePanelBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.myInfo,
      page: () => MyInfoPage(),
      binding: MyInfoBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.myTeam,
      page: () => MyTeamPage(),
      binding: MyTeamBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.accountSetup,
      page: () => AccountSetupPage(),
      binding: AccountSetupBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.blacklist,
      page: () => BlacklistPage(),
      binding: BlacklistBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.languageSetup,
      page: () => LanguageSetupPage(),
      binding: LanguageSetupBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.aboutUs,
      page: () => AboutUsPage(),
      binding: AboutUsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.paymentMethod,
      page: () => PaymentMethodPage(),
      binding: PaymentMethodBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.groupChatSetup,
      page: () => GroupSetupPage(),
      binding: GroupSetupBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.groupManage,
      page: () => GroupManagePage(),
      binding: GroupManageBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.editGroupName,
      page: () => EditGroupNamePage(),
      binding: EditGroupNameBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.groupMemberList,
      page: () => GroupMemberListPage(),
      binding: GroupMemberListBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.groupQrcode,
      page: () => GroupQrcodePage(),
      binding: GroupQrcodeBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.friendRequests,
      page: () => FriendRequestsPage(),
      binding: FriendRequestsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.processFriendRequests,
      page: () => ProcessFriendRequestsPage(),
      binding: ProcessFriendRequestsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.groupRequests,
      page: () => GroupRequestsPage(),
      binding: GroupRequestsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.processGroupRequests,
      page: () => ProcessGroupRequestsPage(),
      binding: ProcessGroupRequestsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.friendList,
      page: () => FriendListPage(),
      binding: FriendListBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.groupList,
      page: () => GroupListPage(),
      binding: GroupListBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.selectContacts,
      page: () => SelectContactsPage(),
      binding: SelectContactsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.selectContactsFromFriends,
      page: () => SelectContactsFromFriendsPage(),
      binding: SelectContactsFromFriendsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.selectContactsFromGroup,
      page: () => SelectContactsFromGroupPage(),
      binding: SelectContactsFromGroupBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.selectContactsFromSearch,
      page: () => SelectContactsFromSearchPage(),
      binding: SelectContactsFromSearchBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.createGroup,
      page: () => CreateGroupPage(),
      binding: CreateGroupBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.globalSearch,
      page: () => GlobalSearchPage(),
      binding: GlobalSearchBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.register,
      page: () => RegisterPage(),
      binding: RegisterBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.verifyPhone,
      page: () => VerifyPhonePage(),
      binding: VerifyPhoneBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.setPassword,
      page: () => SetPasswordPage(),
      binding: SetPasswordBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.setSelfInfo,
      page: () => SetSelfInfoPage(),
      binding: SetSelfInfoBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.forgetPassword,
      page: () => ForgetPasswordPage(),
      binding: ForgetPasswordBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.resetPassword,
      page: () => ResetPasswordPage(),
      binding: ResetPasswordBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.wallet,
      page: () => WalletPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => WalletLogic());
      }),
    ),
    _pageBuilder(
      name: AppRoutes.billDetail,
      page: () => BillDetailPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => BillDetailLogic());
      }),
    ),
    _pageBuilder(
      name: AppRoutes.transfer,
      page: () => TransferPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => TransferLogic());
      }),
    ),
    // _pageBuilder(
    //   name: AppRoutes.wallet,
    //   page: () => WalletPage(),
    //   binding: BindingsBuilder(() {
    //     Get.lazyPut(() => WalletLogic());
    //   }),
    // ),
    // _pageBuilder(
    //   name: AppRoutes.billDetail,
    //   page: () => BillDetailPage(),
    //   binding: BindingsBuilder(() {
    //     Get.lazyPut(() => BillDetailLogic());
    //   }),
    // ),
    // _pageBuilder(
    //   name: AppRoutes.transfer,
    //   page: () => TransferPage(),
    //   binding: BindingsBuilder(() {
    //     Get.lazyPut(() => TransferLogic());
    //   }),
    // ),
    _pageBuilder(
        name: AppRoutes.luckMoney,
        page: () => LuckMoneyPage(),
        binding: LuckMoneyBinding()),
    _pageBuilder(
        name: AppRoutes.selectedMemberList,
        page: () => SelectedMemberListPage(),
        binding: LuckMoneyGroupMemberListBinding()),
    _pageBuilder(
        name: AppRoutes.luckMoneyDetail,
        page: () => LuckMoneyDetailPage(),
        binding: LuckMoneyDetailBinding()),
    _pageBuilder(
        name: AppRoutes.luckMoneyLog,
        page: () => LuckMoneyLogPage(),
        binding: LuckMoneyLogBinding()),
    _pageBuilder(
      name: AppRoutes.muteSetup,
      page: () => MuteSetupView(),
      binding: MuteSetupBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.groupAc,
      page: () => GroupAcView(),
      binding: GroupAcBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.search,
      page: () => SearchView(),
      binding: searchBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.myQrcode,
      page: () => MyQrcodeView(),
      binding: MyQrcodeBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.webViewPage,
      page: () => WebViewPage(),
      binding: WebViewBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.addAcount,
      page: () => AddAcountPageView(),
      binding: AddAcountPageBinding(),
    ),
    _pageBuilder(
        name: AppRoutes.editMyInfo,
        page: () => EditMyInfoPage(),
        binding: EditMyInfoBinding()),
    _pageBuilder(
      name: AppRoutes.accountRegister,
      page: () => AccountRegisterView(),
      binding: AccountRegisterBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.checkin,
      page: () => SignInView(),
      binding: SignInBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.lotteryTickets,
      page: () => LotteryTicketsView(),
      binding: LotteryTicketsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.prizeRecords,
      page: () => PrizeRecordsView(),
      binding: PrizeRecordsBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.checkinRewards,
      page: () => CheckinRewardsView(),
      binding: CheckinRewardsBinding(),
    ),
    // 移除签到规则说明页面路由
    _pageBuilder(
      name: AppRoutes.article,
      page: () => ArticleView(),
      binding: ArticleBinding(),
    ),
    _pageBuilder(
      name: AppRoutes.lotteryWheel,
      page: () => LotteryWheelView(),
      binding: LotteryWheelBinding(),
    ),
  ];
}