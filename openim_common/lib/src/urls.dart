import 'config.dart';

class Urls {
  static final onlineStatus =
      "${Config.imApiUrl}/manager/get_users_online_status";
  static final queryAllUsers = "${Config.imApiUrl}/manager/get_all_users_uid";
  static final updateUserInfo = "${Config.appAuthUrl}/third/user/update_info";
  static final searchFriendInfo = "${Config.appAuthUrl}/friend/search";
  static final getUsersFullInfo = "${Config.appAuthUrl}/third/user/find/full";
  static final searchUserFullInfo =
      "${Config.appAuthUrl}/third/user/search/full";

  static final getVerificationCode = "${Config.appAuthUrl}/account/code/send";
  static final changeEmail = "${Config.appAuthUrl}/third/user/change_email";
  static final checkVerificationCode =
      "${Config.appAuthUrl}/account/code/verify";
  static final register = "${Config.appAuthUrl}/account/register";

  static final resetPwd = "${Config.appAuthUrl}/account/password/reset";
  static final changePwd = "${Config.appAuthUrl}/account/password/change";
  static final login = "${Config.appAuthUrl}/account/login";

  static final upgrade = "${Config.appAuthUrl}/app/check";
  static final getClientConfig = '${Config.appAuthUrl}/client_config/get';
  static final getTokenForRTC = "${Config.appAuthUrl}/user/rtc/get_token";

  static final checkWalletExist = "${Config.appAuthUrl}/third/wallet/exist";
  static final createWallet = "${Config.appAuthUrl}/third/wallet/create";
  static final accountCompare = "${Config.appAuthUrl}/third/account/compare";
  static final walletBalanceByOrg =
      "${Config.appAuthUrl}/third/wallet_balance/get_balance";
  static final walletBalanceRechargeTest =
      "${Config.appAuthUrl}/third/wallet/balance/recharge/test";
  static final walletTokenPage = "${Config.appAuthUrl}/third/wallet/currencies";
  static final exchageRate = "${Config.appAuthUrl}/third/exchange_rate/latest";
  static final rsaPublicKey = "${Config.appAuthUrl}/third/wallet/pay_pwd/key";
  static final walletPayPwdUpdate =
      "${Config.appAuthUrl}/third/wallet/pay_pwd/update";
  static final compensationInit =
      "${Config.appAuthUrl}/third/wallet/compensation/init";
  static final walletTsRecordDetail =
      "${Config.appAuthUrl}/third/walletTsRecord/ts/detail";
  static final rsaPublicKeySetUp = "${Config.appAuthUrl}/third/user_keys/setup";
  static final transactionCreate =
      "${Config.appAuthUrl}/third/transaction/create";
  static final transactionReceive =
      "${Config.appAuthUrl}/third/transaction/receive";
  static final walletTsRecord = "${Config.appAuthUrl}/third/walletTsRecord/ts";
  static final transactionReceiveHistory =
      "${Config.appAuthUrl}/third/transaction/receive_history";
  static final transactionCheckReceived =
      "${Config.appAuthUrl}/third/transaction/check_received";
  static final transactionCheckCompleted =
      "${Config.appAuthUrl}/third/transaction/check_completed";
  static final transactionReceiveDetails =
      "${Config.appAuthUrl}/third/transaction/receive_details";

  static final approveHandRaise =
      "${Config.appAuthUrl}/third/livestream/approve_hand_raise";
  static final removeFromStage =
      "${Config.appAuthUrl}/third/livestream/remove_from_stage";
  static final createStream =
      "${Config.appAuthUrl}/third/livestream/create_stream";
  static final joinStream = "${Config.appAuthUrl}/third/livestream/join_stream";
  static final raiseHand = "${Config.appAuthUrl}/third/livestream/raise_hand";
  static final inviteToStage =
      "${Config.appAuthUrl}/third/livestream/invite_to_stage";
  static final blockViewer =
      "${Config.appAuthUrl}/third/livestream/block_viewer";
  static final stopStream = "${Config.appAuthUrl}/third/livestream/stop_stream";
  static final setAdmin = "${Config.appAuthUrl}/third/livestream/set_admin";
  static final revokeAdmin =
      "${Config.appAuthUrl}/third/livestream/revoke_admin";
  static final livestreamStatisticsSingle =
      "${Config.appAuthUrl}/third/livestream_statistics/single";
  static final livestreamStatisticsList =
      "${Config.appAuthUrl}/third/livestream_statistics/list";

  // 组织用户
  static final selfAllOrg =
      "${Config.appAuthUrl}/third/organization_user/get_self_all_org";
  static final orgRule =
      "${Config.appAuthUrl}/third/organization_role_permission/get_self_org_role_permission";
  static final changeOrgUser =
      "${Config.appAuthUrl}/third/organization_user/change_org_user";
  static final joinInvitation =
      "${Config.appAuthUrl}/third/organization/join_using_invitation_code";
  static final checkUserProtection =
      "${Config.appAuthUrl}/third_admin/organization/internal/check_user_protection";
  static final appLogUpload = "${Config.appAuthUrl}/third/app_log/upload";
  // dawn 2026-05-15 修复手机端发送方敏感词未脱敏：客户端发送前读取启用词表。
  static final sensitiveWordEnabled =
      "${Config.appAuthUrl}/third/sensitive_word/enabled";

  // 注册账户-new
  static final userRegister = "${Config.appAuthUrl}/third/user/register";
  static final userAcountRegister =
      "${Config.appAuthUrl}/third/user/register_via_account";
  static final captcha = "${Config.appAuthUrl}/third/captcha/image";

  // 签到&转盘活动
  static final checkinHistory = "${Config.appAuthUrl}/third/checkin/detail";
  static final checkin = "${Config.appAuthUrl}/third/checkin/create";
  static final checkinRule = "${Config.appAuthUrl}/third/checkin/rule";
  static final checkinRewards =
      "${Config.appAuthUrl}/third/checkin_reward/list";
  static final prizeRecord =
      "${Config.appAuthUrl}/third/lottery_user_record/list";
  static final lotterys =
      "${Config.appAuthUrl}/third/lottery_user_ticket/detail";
  static final lotteryDetail = "${Config.appAuthUrl}/third/lottery/detail";
  static final lotteryTicketUse =
      "${Config.appAuthUrl}/third/lottery_user_ticket/use";

  // 文章
  static final articleDetail = "${Config.appAuthUrl}/third/article";

  // 收款方式
  static final paymentMethods =
      "${Config.appAuthUrl}/third/user/payment-methods";

  // 身份认证
  static final identitySubmit =
      "${Config.appAuthUrl}/third/user/identity/submit";
  static final identityInfo = "${Config.appAuthUrl}/third/user/identity/info";

  // 提现相关
  static final withdrawalRule =
      "${Config.appAuthUrl}/third/wallet/withdrawal/rule";
  static final withdrawalSubmit =
      "${Config.appAuthUrl}/third/wallet/withdrawal/submit";
  static final withdrawalRecords =
      "${Config.appAuthUrl}/third/wallet/withdrawal/records";
  static final withdrawalDetailByOrderNo =
      "${Config.appAuthUrl}/third/wallet/withdrawal/detail";
  static final withdrawalCancel =
      "${Config.appAuthUrl}/third/wallet/withdrawal/cancel";
  static final withdrawalCheckPending =
      "${Config.appAuthUrl}/third/wallet/withdrawal/check-pending";

  // 文件上传相关
  static final getUploadPartSize = "${Config.imApiUrl}/object/part_size";
  static final getUploadUrl =
      "${Config.imApiUrl}/object/initiate_multipart_upload";
  static final confirmUpload =
      "${Config.imApiUrl}/object/complete_multipart_upload";

  /// 按 seq 区间从服务端拉取消息（用于群聊上翻分段拉取历史）
  static final pullMsgBySeq = "/msg/pull_msg_by_seq";

  /// 获取各会话最大 seq（用于本地无消息时确定拉取范围）
  static final newestSeq = "/msg/newest_seq";
}
