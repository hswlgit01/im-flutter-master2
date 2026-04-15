import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/captcha.dart';
import 'package:openim_common/src/models/change_org_data.dart';
import 'package:openim_common/src/models/checkin_histore.dart';
import 'package:openim_common/src/models/checkin_reward.dart';
import 'package:openim_common/src/models/lottery.dart';
import 'package:openim_common/src/models/lottery_ticket.dart';
import 'package:openim_common/src/models/org_list.dart';
import 'package:openim_common/src/models/org_rule.dart';
import 'package:openim_common/src/models/paged_response.dart';
import 'package:openim_common/src/models/payment_method.dart';
import 'package:openim_common/src/models/register_res.dart';
import 'package:openim_common/src/models/withdrawal_info.dart';
import 'package:openim_common/src/models/team_info.dart';
import 'package:sprintf/sprintf.dart';

import 'utils/api_service.dart';

class Apis {
  static Options get imTokenOptions =>
      Options(headers: {'token': DataSp.imToken});

  static Options get chatTokenOptions =>
      Options(
        headers: {
          'token': DataSp.chatToken,
          'Content-Type': 'application/json',
        },
      );

  static StreamController kickoffController = StreamController<int>.broadcast();

  static void _kickoff(int? errCode) {
    if (errCode == 1501 ||
        errCode == 1503 ||
        errCode == 1504 ||
        errCode == 1505) {
      kickoffController.sink.add(errCode);
    }
  }

  /// 将 catch 到的异常统一解析为 (errCode, errMsg)。
  /// 业务错误为 (int, String?)；Dio 超时/网络错误等会转为 (-1, message)，避免类型转换崩溃。
  static (int, String?) _parseApiError(Object e) {
    if (e is (int, String?)) return e;
    final msg = e is Exception ? e.toString() : '$e';
    return (-1, msg);
  }

  static Future<LoginCertificate> login({
    String? areaCode,
    String? phoneNumber,
    String? account,
    String? email,
    String? password,
    String? verificationCode,
  }) async {
    try {
      final loginUrl = Urls.login;
      Logger.print('🔐 登录请求 URL: $loginUrl');
      var data = await HttpUtil.post(loginUrl, data: {
        "areaCode": areaCode,
        'account': account,
        'phoneNumber': phoneNumber,
        'email': email,
        'password': null != password ? IMUtils.generateMD5(password) : null,
        'platform': IMUtils.getPlatform(),
        'verifyCode': verificationCode,
      });
      final cert = LoginCertificate.fromJson(data!);
      ApiService().setToken(cert.imToken);

      return cert;
    } catch (e, _) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  static Future<LoginCertificate> register({
    required String nickname,
    required String password,
    String? faceURL,
    String? areaCode,
    String? phoneNumber,
    String? email,
    String? account,
    int birth = 0,
    int gender = 1,
    required String verificationCode,
    String? invitationCode,
  }) async {
    try {
      var data = await HttpUtil.post(
        Urls.register,
        data: {
          'deviceID': DataSp.getDeviceID(),
          'verifyCode': verificationCode,
          'platform': IMUtils.getPlatform(),
          'invitationCode': invitationCode,
          'autoLogin': true,
          'user': {
            "nickname": nickname,
            "faceURL": faceURL,
            'birth': birth,
            'gender': gender,
            'email': email,
            "areaCode": areaCode,
            'phoneNumber': phoneNumber,
            'account': account,
            'password': IMUtils.generateMD5(password),
          },
        },
      );

      final cert = LoginCertificate.fromJson(data!);
      ApiService().setToken(cert.imToken);

      return cert;
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  static Future<RegisterRes> userRegister(
      {required String account,
      required String password,
      String? faceURL,
      String? areaCode,
      String? phoneNumber,
      required String nickname,
      String? email,
      int birth = 0,
      int gender = 1,
      required String verificationCode,
      required String orgInvitationCode,
      String? invitationCode,
      }) async {
    try {
      var data = await HttpUtil.post(
        Urls.userRegister,
        data: {
          'deviceID': DataSp.getDeviceID(),
          'verifyCode': verificationCode,
          'platform': IMUtils.getPlatform(),
          'invitationCode': invitationCode,

          'autoLogin': true,
          'user': {
            "nickname": nickname,
            "account": account,
            "faceURL": faceURL,
            'birth': birth,
            'gender': gender,
            'email': email,
            "areaCode": areaCode,
            'phoneNumber': phoneNumber,
            'password': IMUtils.generateMD5(password),
          },
          'orgInvitationCode': orgInvitationCode
        },
      );

      final cert = RegisterRes.fromJson(data!);
      ApiService().setToken(cert.imToken!);

      return cert;
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  static Future<RegisterRes> userAcountRegister(
      {required String password,
      required String account,
      required String orgInvitationCode,
      required String nickname,
      required String captchaId,
      required String captchaAnswer,
      required String deviceCode}) async {
    try {
      var data = await HttpUtil.post(
        Urls.userAcountRegister,
        data: {
          'platform': IMUtils.getPlatform(),
          'autoLogin': true,
          'orgInvitationCode': orgInvitationCode,
          'captchaId': captchaId,
          'captchaAnswer': captchaAnswer,
          'deviceCode': deviceCode,
          'user': {
            "nickname": nickname,
            "faceURL": "",
            'account': account,
            'password': IMUtils.generateMD5(password),
          },
        },
      );

      final cert = RegisterRes.fromJson(data!);
      ApiService().setToken(cert.imToken!);

      return cert;
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  static Future<Captcha> getCaptcha() async {
    try {
      var data = await HttpUtil.get(Urls.captcha, options: chatTokenOptions);
      return Captcha.fromJson(data);
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  static Future<dynamic> resetPassword({
    String? areaCode,
    String? phoneNumber,
    String? email,
    required String password,
    required String verificationCode,
  }) async {
    try {
      return HttpUtil.post(
        Urls.resetPwd,
        data: {
          // "areaCode": areaCode,
          'phoneNumber': phoneNumber,
          'email': email,
          'password': IMUtils.generateMD5(password),
          'verifyCode': verificationCode,
          'platform': IMUtils.getPlatform(),
        },
        options: chatTokenOptions,
      );
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
    }
  }

  static Future<bool> changePassword({
    required String userID,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await HttpUtil.post(
        Urls.changePwd,
        data: {
          "userID": userID,
          'currentPassword': IMUtils.generateMD5(currentPassword),
          'newPassword': IMUtils.generateMD5(newPassword),
          'platform': IMUtils.getPlatform(),
        },
        options: chatTokenOptions,
      );
      return true;
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return false;
    }
  }

  static Future<bool> changePasswordOfB({
    required String newPassword,
  }) async {
    try {
      await HttpUtil.post(
        Urls.resetPwd,
        data: {
          'password': IMUtils.generateMD5(newPassword),
          'platform': IMUtils.getPlatform(),
        },
        options: chatTokenOptions,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取各会话最大 seq（用于群聊本地无消息时确定拉取范围）
  /// 返回 data：{ maxSeqs: { conversationID: seq (int) }, minSeqs: {...} }，失败返回 null
  static Future<Map<String, dynamic>?> getNewestSeq({required String userID}) async {
    try {
      final data = await HttpUtil.post(
        Urls.newestSeq,
        data: {'userID': userID},
        options: imTokenOptions,
        showErrorToast: false,
      );
      return data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// 按 seq 区间从服务端拉取消息（群聊上翻分段拉取历史）
  /// [userID] 当前用户 ID
  /// [seqRanges] 每个元素: conversationID, begin, end, num
  /// [order] 0=Asc 拉新消息, 1=Desc 拉更早消息
  /// 返回 data：{ msgs: { conversationID: { msgs: [...], isEnd: bool } }, notificationMsgs: {...} }，失败返回 null
  static Future<Map<String, dynamic>?> pullMessageBySeqs({
    required String userID,
    required List<Map<String, dynamic>> seqRanges,
    int order = 1,
  }) async {
    try {
      final opts = Options(
        headers: imTokenOptions.headers,
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      );
      final data = await HttpUtil.post(
        Urls.pullMsgBySeq,
        data: {
          'userID': userID,
          'seqRanges': seqRanges,
          'order': order,
        },
        options: opts,
        showErrorToast: false,
      );
      return data as Map<String, dynamic>?;
    } catch (e, st) {
      Logger.print('pullMessageBySeqs 失败: $e\n$st');
      return null;
    }
  }

  static Future<dynamic> updateUserInfo({
    required String userID,
    String? account,
    String? phoneNumber,
    String? areaCode,
    String? email,
    String? nickname,
    String? faceURL,
    int? gender,
    int? birth,
    int? level,
    int? allowAddFriend,
    int? allowBeep,
    int? allowVibration,
  }) async {
    try {
      Map<String, dynamic> param = {'userID': userID};
      void put(String key, dynamic value) {
        if (null != value) {
          param[key] = value;
        }
      }

      put('account', account);
      put('phoneNumber', phoneNumber);
      put('areaCode', areaCode);
      put('email', email);
      put('nickname', nickname);
      put('faceURL', faceURL);
      put('gender', gender);
      put('level', level);
      put('birth', birth);
      put('allowAddFriend', allowAddFriend);
      put('allowBeep', allowBeep);
      put('allowVibration', allowVibration);

      return HttpUtil.post(
        Urls.updateUserInfo,
        data: {
          ...param,
          'platform': IMUtils.getPlatform(),
        },
        options: chatTokenOptions,
      );
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
    }
  }

  static Future<List<FriendInfo>> searchFriendInfo(
    String keyword, {
    int pageNumber = 1,
    int showNumber = 10,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.searchFriendInfo,
        data: {
          'pagination': {'pageNumber': pageNumber, 'showNumber': showNumber},
          'keyword': keyword,
        },
        options: chatTokenOptions,
      );
      if (data['users'] is List) {
        return (data['users'] as List)
            .map((e) => FriendInfo.fromJson(e))
            .toList();
      }
      return [];
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return [];
    }
  }

  static Future<List<UserFullInfo>?> getUserFullInfo({
    int pageNumber = 0,
    int showNumber = 10,
    required List<String> userIDList,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.getUsersFullInfo,
        data: {
          'pagination': {'pageNumber': pageNumber, 'showNumber': showNumber},
          'userIDs': userIDList,
          'platform': IMUtils.getPlatform(),
        },
        options: chatTokenOptions,
      );
      if (data['users'] is List) {
        return (data['users'] as List)
            .map((e) => UserFullInfo.fromJson(e))
            .toList();
      }
      return null;
    } catch (e, s) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('e:$errCode s:$errMsg');
      } else {
        Logger.print('getUserFullInfo error (e.g. timeout/network): $e');
      }
      return [];
    }
  }

  static Future<List<UserFullInfo>?> searchUserFullInfo({
    required String content,
    int pageNumber = 1,
    int showNumber = 10,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.searchUserFullInfo,
        data: {
          'pagination': {'pageNumber': pageNumber, 'showNumber': showNumber},
          'keyword': content,
        },
        options: chatTokenOptions,
      );
      if (data['users'] is List) {
        return (data['users'] as List)
            .map((e) => UserFullInfo.fromJson(e))
            .toList();
      }
      return null;
    } catch (e, s) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('e:$errCode s:$errMsg');
      } else {
        Logger.print('searchUserFullInfo error (e.g. timeout/network): $e');
      }
      return [];
    }
  }

  static Future<UserFullInfo?> queryMyFullInfo() async {
    final list = await Apis.getUserFullInfo(
      userIDList: [OpenIM.iMManager.userID],
    );
    return list?.firstOrNull;
  }

  // 获取用户团队信息
  static Future<TeamInfo?> getUserTeamInfo() async {
    try {
      // 使用 appAuthUrl 而不是 imApiUrl，确保端口正确
      final result = await HttpUtil.get(
        '${Config.appAuthUrl}/third/user/team/info',
        options: chatTokenOptions,
      );

      if (result is Map<String, dynamic>) {
        return TeamInfo.fromJson(result);
      }
      return null;
    } catch (e, s) {
      Logger.print('获取团队信息失败 e:$e s:$s');
      return null;
    }
  }

  static Future<bool> requestVerificationCode({
    String? areaCode,
    String? phoneNumber,
    String? email,
    required int usedFor,
    String? invitationCode,
  }) async {
    return HttpUtil.post(
      Urls.getVerificationCode,
      data: {
        "areaCode": email == null ? areaCode : null,
        "phoneNumber": phoneNumber,
        "email": email,
        'usedFor': usedFor,
        'invitationCode': invitationCode
      },
    ).then((value) {
      IMViews.showToast(StrRes.sentSuccessfully);
      return true;
    }).catchError((e, s) {
      Logger.print('e:$e s:$s');
      return false;
    });
  }

  static Future<SignalingCertificate> getTokenForRTC(
      String roomID, String userID) async {
    try {
      final value = await HttpUtil.post(
        Urls.getTokenForRTC,
        data: {
          "room": roomID,
          "identity": userID,
        },
        options: chatTokenOptions,
      );
      final map = Map<String, dynamic>.from(value as Map);
      final signaling = SignalingCertificate.fromJson(map)..roomID = roomID;
      if (signaling.token == null || signaling.token!.isEmpty) {
        throw StateError('RTC token 为空');
      }
      if (signaling.liveURL == null || signaling.liveURL!.isEmpty) {
        throw StateError('没有可用的 LiveKit 服务地址（serverUrl）');
      }
      return signaling;
    } catch (e, s) {
      Logger.print('getTokenForRTC e:$e s:$s');
      rethrow;
    }
  }

  static Future<dynamic> checkVerificationCode({
    String? areaCode,
    String? phoneNumber,
    String? email,
    required String verificationCode,
    required int usedFor,
    String? invitationCode,
  }) {
    return HttpUtil.post(
      Urls.checkVerificationCode,
      data: {
        "phoneNumber": phoneNumber,
        "areaCode": areaCode,
        "email": email,
        "verifyCode": verificationCode,
        "usedFor": usedFor,
        'invitationCode': invitationCode
      },
    );
  }

  // 修改邮箱
  static Future<dynamic> updateEmail(
      {required String newEmail, required String verifyCode}) {
    return HttpUtil.post(
      Urls.changeEmail,
      options: chatTokenOptions,
      data: {
        "new_email": newEmail,
        "verify_code": verifyCode,
      },
    );
  }

  static Future<Map<String, dynamic>> getClientConfig() async {
    return {
      'discoverPageURL': Config.discoverPageURL,
      'allowSendMsgNotFriend': Config.allowSendMsgNotFriend
    };
  }

  static void _catchError(Object e, StackTrace s, {bool forceBack = true}) {
    if (e is ApiException) {
      var msg = '${e.code}'.tr;
      if (msg.isEmpty || e.code.toString() == msg) {
        msg = e.message ?? 'Unkonw error';
      } else if (e.code == 1004) {
        msg = sprintf(msg, [StrRes.meeting]);
      }

      IMViews.showToast(msg);

      if ((e.code == 10010 || e.code == 10002) && forceBack) {
        DataSp.removeLoginCertificate();
        Get.offAllNamed('/login');
      }
    } else {
      IMViews.showToast(e.toString());
    }
  }

  // 当前用户下所有组织
  static Future<OrgListData> getSelfAllOrg() async {
    try {
      final data = await HttpUtil.get(
        Urls.selfAllOrg,
        options: chatTokenOptions,
      );
      return OrgListData.fromJson(data);
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  // 当前用户再所在组织的权限
  static Future<List<OrgRule>> getSelfOrgRules() async {
    try {
      final data = await HttpUtil.get(
        Urls.orgRule,
        options: chatTokenOptions,
      );
      print("object");
      if (data is List) {
        return OrgRule.fromList(data.cast<Map<String, dynamic>>());
      }
      return [];
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  static Future<ChangeOrgData> changeOrgUser(String orgId) async {
    try {
      final data = await HttpUtil.post(Urls.changeOrgUser,
          options: chatTokenOptions,
          data: {
            "org_id": orgId,
            "platform": IMUtils.getPlatform(),
          });
      return ChangeOrgData.fromJson(data);
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  /// 加入组织邀请
  static Future<dynamic> joinInvitation(String code,
      {required String nickname, required String faceUrl}) async {
    try {
      final data = await HttpUtil.post(Urls.joinInvitation,
          options: chatTokenOptions,
          data: {
            "invitation_code": code,
            "nickname": nickname,
            "face_url": faceUrl,
          });
      return data;
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  /// 查询打卡记录
  static Future<CheckinHistore> queryCheckinRecord(
      {int? startTime, int? endTime}) async {
    try {
      final data = await HttpUtil.get(Urls.checkinHistory,
          options: chatTokenOptions,
          queryParameters: {
            "startTime": startTime ?? '',
            "endTime": endTime ?? '',
          });
      return CheckinHistore.fromJson(data);
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  /// 打卡（签到）。返回本次签到后的连续签到天数、今日签到记录与奖励列表，供前端直接回显
  static Future<CheckinResult> checkin() async {
    try {
      final data = await HttpUtil.post(Urls.checkin, options: chatTokenOptions);

      if (data is Map<String, dynamic>) {
        return CheckinResult.fromJson(data);
      }

      return CheckinResult(streak: 0, checkinRewards: []);
    } catch (e, _) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }


  /// 获取签到规则说明
  static Future<String> getCheckinRuleDescription() async {
    try {
      final data = await HttpUtil.get(
        Urls.checkinRule,
        options: chatTokenOptions,
      );

      if (data != null && data['checkin_rule'] != null) {
        final ruleText = data['checkin_rule'].toString();
        return ruleText.isNotEmpty ? ruleText : '';
      }

      // 如果返回数据为空或没有checkin_rule字段，返回空字符串
      return '';
    } catch (e, s) {
      // 如果API调用失败，返回空字符串
      Logger.print('获取签到规则失败: $e');
      return '';
    }
  }

  /// 获取打卡奖励
  static Future<PagedResponse<CheckinReward>> getCheckinRewards({
    required int page,
    required int pageSize,
    String? status,
  }) async {
    try {
      final data = await HttpUtil.get(Urls.checkinRewards,
          options: chatTokenOptions,
          queryParameters: {
            "page": page,
            "pageSize": pageSize,
            if (status?.isNotEmpty == true) "status": status,
          });
      return PagedResponse<CheckinReward>.fromJson(
        data as Map<String, dynamic>,
        CheckinReward.fromJson,
      );
    } catch (e, _) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  /// 获取抽奖券抽奖奖品列表
  static Future<PagedResponse<Lottery>> getPrizeRecord({
    required int page,
    required int pageSize,
    int? status,
  }) async {
    try {
      final data = await HttpUtil.post(Urls.prizeRecord,
          options: chatTokenOptions,
          data: {
            'page': page,
            'page_size': pageSize,
            if (status != null) 'status': status,
          });
      return PagedResponse<Lottery>.fromJson(
        data as Map<String, dynamic>,
        Lottery.fromJson,
      );
    } catch (e, _) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  /// 获取抽奖券列表
  static Future<PagedResponse<LotteryTicket>> getLotterys({
    required int page,
    required int pageSize,
  }) async {
    try {
      final data = await HttpUtil.get(
        Urls.lotterys,
        options: chatTokenOptions,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );
      return PagedResponse<LotteryTicket>.fromJson(
        data as Map<String, dynamic>,
        LotteryTicket.fromJson,
      );
    } catch (e, _) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  /// 获取抽奖轮盘详情
  static Future<dynamic> getLotteryDetail({
    required String id,
  }) async {
    try {
      final data = await HttpUtil.get(
        Urls.lotteryDetail,
        queryParameters: {
          'id': id,
        },
        options: chatTokenOptions,
      );
      return data;
    } catch (e, _) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  /// 使用抽奖券进行抽奖
  static Future<dynamic> useLotteryTicket({
    required String lotteryTicketId,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.lotteryTicketUse,
        options: chatTokenOptions,
        data: {
          'lottery_ticket_id': lotteryTicketId,
        },
      );
      return data;
    } catch (e, _) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  /// 获取文章详情
  static Future<dynamic> getArticleDetail(String articleId) async {
    try {
      final data = await HttpUtil.get(
        '${Urls.articleDetail}/$articleId',
        options: chatTokenOptions,
      );
      return data;
    } catch (e, s) {
      final t = _parseApiError(e);
      final errCode = t.$1;
      final errMsg = t.$2;
      _kickoff(errCode);
      Logger.print('e:$errCode s:$errMsg');
      return Future.error(e);
    }
  }

  // ==================== 收款方式相关API ====================

  /// 获取支付方式列表
  static Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final data = await HttpUtil.get(
        Urls.paymentMethods,
        options: chatTokenOptions,
      );
      return (data as List)
          .map((e) => PaymentMethod.fromJson(e))
          .toList();
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('e:$errCode s:$errMsg');
      } else {
        Logger.print('getPaymentMethods error: $e');
      }
      return Future.error(e);
    }
  }

  /// 添加银行卡
  static Future<PaymentMethod> addBankCard({
    required String cardNumber,
    required String bankName,
    required String branchName,
    required String accountName,
    bool isDefault = false,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.paymentMethods,
        data: {
          'type': PaymentMethodType.bankCard.index,
          'cardNumber': cardNumber,
          'bankName': bankName,
          'branchName': branchName,
          'accountName': accountName,
          'isDefault': isDefault,
        },
        options: chatTokenOptions,
      );
      return PaymentMethod.fromJson(data);
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('e:$errCode s:$errMsg');
      } else {
        Logger.print('addBankCard error: $e');
      }
      return Future.error(e);
    }
  }

  /// 添加二维码支付方式
  static Future<PaymentMethod> addQRCodePayment({
    required PaymentMethodType type,
    required String qrCodeUrl,
    required String accountName,
    bool isDefault = false,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.paymentMethods,
        data: {
          'type': type.index,
          'qrCodeUrl': qrCodeUrl,
          'accountName': accountName,
          'isDefault': isDefault,
        },
        options: chatTokenOptions,
      );
      return PaymentMethod.fromJson(data);
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('e:$errCode s:$errMsg');
      } else {
        Logger.print('addQRCodePayment error: $e');
      }
      return Future.error(e);
    }
  }

  /// 设置默认支付方式
  static Future<void> setDefaultPaymentMethod(String paymentMethodId) async {
    try {
      await HttpUtil.post(
        '${Urls.paymentMethods}/$paymentMethodId/default',
        options: chatTokenOptions,
      );
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('e:$errCode s:$errMsg');
      } else {
        Logger.print('setDefaultPaymentMethod error: $e');
      }
      return Future.error(e);
    }
  }

  /// 删除支付方式
  static Future<void> deletePaymentMethod(String paymentMethodId) async {
    try {
      await HttpUtil.post(
        '${Urls.paymentMethods}/$paymentMethodId/delete',
        options: chatTokenOptions,
      );
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('e:$errCode s:$errMsg');
      } else {
        Logger.print('deletePaymentMethod error: $e');
      }
      return Future.error(e);
    }
  }

  /// 提交身份认证
  static Future<Map<String, dynamic>> submitIdentity({
    required String realName,
    required String idCardNumber,
    required String idCardFront,
    required String idCardBack,
  }) async {
    try {
      var data = await HttpUtil.post(
        Urls.identitySubmit,
        data: {
          'realName': realName,
          'idCardNumber': idCardNumber,
          'idCardFront': idCardFront,
          'idCardBack': idCardBack,
        },
        options: chatTokenOptions,
      );
      return data ?? {};
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('submitIdentity error code:$errCode msg:$errMsg');
      } else {
        Logger.print('submitIdentity error: $e');
      }
      return Future.error(e);
    }
  }

  /// 获取身份认证信息
  static Future<IdentityVerifyInfo?> getIdentityInfo() async {
    try {
      var data = await HttpUtil.get(
        Urls.identityInfo,
        options: chatTokenOptions,
      );
      if (data != null) {
        return IdentityVerifyInfo.fromJson(data);
      }
      return null;
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('getIdentityInfo error code:$errCode msg:$errMsg');
      } else {
        Logger.print('getIdentityInfo error: $e');
      }
      return Future.error(e);
    }
  }

  /// 获取提现规则
  static Future<WithdrawalRule?> getWithdrawalRule() async {
    try {
      var data = await HttpUtil.get(
        Urls.withdrawalRule,
        options: chatTokenOptions,
      );
      if (data != null) {
        return WithdrawalRule.fromJson(data);
      }
      return null;
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('getWithdrawalRule error code:$errCode msg:$errMsg');
      } else {
        Logger.print('getWithdrawalRule error: $e');
      }
      return Future.error(e);
    }
  }

  /// 提交提现申请
  static Future<Map<String, dynamic>?> submitWithdrawal({
    required double amount,
    required String paymentMethodId,
    required String payPassword,
    String? currencyId,  // 可选的币种ID
  }) async {
    try {
      final requestData = {
        'amount': amount,
        'paymentMethodId': paymentMethodId,
        'payPassword': payPassword,
      };

      // 如果提供了币种ID，添加到请求中
      if (currencyId != null && currencyId.isNotEmpty) {
        requestData['currencyId'] = currencyId;
      }

      var data = await HttpUtil.post(
        Urls.withdrawalSubmit,
        data: requestData,
        options: chatTokenOptions,
      );
      return data;
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('submitWithdrawal error code:$errCode msg:$errMsg');
      } else {
        Logger.print('submitWithdrawal error: $e');
      }
      return Future.error(e);
    }
  }

  /// 获取提现记录列表
  static Future<Map<String, dynamic>?> getWithdrawalRecords({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      var data = await HttpUtil.get(
        Urls.withdrawalRecords,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
        },
        options: chatTokenOptions,
      );
      return data;
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('getWithdrawalRecords error code:$errCode msg:$errMsg');
      } else {
        Logger.print('getWithdrawalRecords error: $e');
      }
      return Future.error(e);
    }
  }

  /// 获取提现详情
  static Future<Map<String, dynamic>?> getWithdrawalDetail(String orderNo) async {
    try {
      var data = await HttpUtil.get(
        '${Urls.withdrawalDetailByOrderNo}/$orderNo',
        options: chatTokenOptions,
      );
      return data;
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('getWithdrawalDetail error code:$errCode msg:$errMsg');
      } else {
        Logger.print('getWithdrawalDetail error: $e');
      }
      return Future.error(e);
    }
  }

  /// 取消提现
  static Future<void> cancelWithdrawal(String orderNo) async {
    try {
      await HttpUtil.post(
        Urls.withdrawalCancel,
        data: {
          'orderNo': orderNo,
        },
        options: chatTokenOptions,
      );
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('cancelWithdrawal error code:$errCode msg:$errMsg');
      } else {
        Logger.print('cancelWithdrawal error: $e');
      }
      return Future.error(e);
    }
  }

  /// 检查是否有未处理的提现申请
  static Future<Map<String, dynamic>?> checkPendingWithdrawal() async {
    try {
      var data = await HttpUtil.get(
        Urls.withdrawalCheckPending,
        options: chatTokenOptions,
      );
      return data;
    } catch (e, _) {
      if (e is (int, String?)) {
        final errCode = e.$1;
        final errMsg = e.$2;
        _kickoff(errCode);
        Logger.print('checkPendingWithdrawal error code:$errCode msg:$errMsg');
      } else {
        Logger.print('checkPendingWithdrawal error: $e');
      }
      return Future.error(e);
    }
  }
}
