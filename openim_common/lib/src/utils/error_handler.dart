import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:dio/dio.dart';

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  // 错误码映射
  static final Map<int, String> _errorCodeMap = {
    // 系统错误 (10000-10099)
    10000: 'errCode.systemError',
    10001: 'errCode.invalidParams',
    10002: 'errCode.unauthorized',
    10003: 'errCode.forbidden',
    10004: 'errCode.tooFrequent',
    10005: 'errCode.notFound',
    10006: 'errCode.serverInternalError',
    10007: 'errCode.invalidPageParams',
    10010: 'errCode.liveKitUrlError',
    10090: 'errCode.apiError',
    10091: 'errCode.captchaError',

    // 交易错误 (10100-10199)
    10100: 'errCode.insufficientBalance',
    10101: 'errCode.transactionExpired',
    10102: 'errCode.transactionNotFound',
    10103: 'errCode.invalidAmount',
    10104: 'errCode.alreadyReceived',
    10105: 'errCode.notInGroup',
    10106: 'errCode.notFriend',
    10107: 'errCode.walletNotOpen',
    10108: 'errCode.walletOpened',
    10109: 'errCode.noRemaining',
    10110: 'errCode.distributedLock',
    10111: 'errCode.redPacketCountExceed',
    10112: 'errCode.redPacketAmountNotDivisible',
    10113: 'errCode.walletBalanceNotOpen',
    10130: 'errCode.operationTooFrequent', // 操作过于频繁（预留未完成）

    // 余额错误 (10200-10299)
    10200: 'errCode.balanceNotFound',
    10201: 'errCode.balanceUpdateFail',
    10300: 'errCode.deviceRegisterNumExceed',
    10400: 'errCode.invalidInvitationCode',

    // 账户错误 (11000-11500)
    11002: 'errCode.userAccountError',
    11003: 'errCode.userNotFound',
    11004: 'errCode.userPwdError',
    11005: 'errCode.emailInUse',
    11006: 'errCode.accountExists',

    // 直播错误 (11500-12000)
    11501: 'errCode.liveStreamRoomNotFound',
    11510: 'errCode.liveStreamRoomExecutePermission',
    11511: 'errCode.liveStreamRoomParticipantPermission',
    11512: 'errCode.liveStreamParticipantBlocked',
    11520: 'errCode.liveStreamSystemError',

    // 原有错误码
    20001: 'errCode.passwordError',
    20002: 'errCode.accountNotExist',
    20003: 'errCode.phoneNumberRegistered',
    20004: 'errCode.accountRegistered',
    20005: 'errCode.operationTooFrequent',
    20006: 'errCode.verificationCodeError',
    20007: 'errCode.verificationCodeExpired',
    20008: 'errCode.verificationCodeErrorLimitExceed',
    20009: 'errCode.verificationCodeUsed',
    20010: 'errCode.invitationCodeUsed',
    20011: 'errCode.invitationCodeNotExist',
    20012: 'errCode.operationRestriction',
    20014: 'errCode.accountRegistered',
  };

  // 获取错误信息
  String getErrorMessage(int errorCode) {
    final key = _errorCodeMap[errorCode];
    if (key != null) {
      return key.tr;
    }
    return 'errCode.unknown'.tr;
  }

  // 处理API错误
  void handleApiError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        // case DioExceptionType.connectionError:
        //   IMViews.showToast('errCode.network'.tr);
        //   break;
        case DioExceptionType.connectionTimeout:
          IMViews.showToast('errCode.timeout'.tr);
          break;
        default:
        // IMViews.showToast('errCode.serviceUnavailable'.tr);
      }
    } else {
      IMViews.showToast('errCode.unknown'.tr);
    }
  }

  // 处理网络错误
  void handleNetworkError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
          IMViews.showToast('errCode.network'.tr);
          break;
        case DioExceptionType.connectionTimeout:
          IMViews.showToast('errCode.timeout'.tr);
          break;
        default:
          IMViews.showToast('errCode.serviceUnavailable'.tr);
      }
    } else {
      IMViews.showToast('errCode.unknown'.tr);
    }
  }

  // 处理业务错误
  void handleBusinessError(int errorCode, {String? customMessage}) {
    if (errorCode == 10090 &&
        customMessage != null &&
        customMessage.trim().isNotEmpty) {
      var message = customMessage.trim();
      const prefix = 'api error: ';
      if (message.toLowerCase().startsWith(prefix)) {
        message = message.substring(prefix.length).trim();
      }
      IMViews.showToast(message);
      return;
    }

    final message = getErrorMessage(errorCode);

    if ('errCode.unknown'.tr == message) {
      if (customMessage != null) {
        IMViews.showToast(customMessage);
        return;
      }
    }
    IMViews.showToast(message);

    // 处理特殊错误码
    switch (errorCode) {
      case 10002: // 未授权 - 需要重新登录
        // 需要重新登录
        Get.offAllNamed('/login');
        break;
      // 注意: 10003(禁止访问)不一定是认证问题,可能是业务逻辑限制(如重复提现)
      // 因此不应该自动跳转登录页面
    }
  }
}
