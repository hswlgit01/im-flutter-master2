import 'dart:convert';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';
import 'package:uuid/uuid.dart';

class DataSp {
  static const _loginCertificate = 'loginCertificate';
  static const _loginAccount = 'loginAccount';
  static const _server = "server";
  static const _ip = 'ip';
  static const _deviceID = 'deviceID';
  static const _ignoreUpdate = 'ignoreUpdate';
  static const _language = "language";
  static const _groupApplication = "%s_groupApplication";
  static const _friendApplication = "%s_friendApplication";
  static const _walletStatus = "%s_walletStatus";
  static const _remoteConfig = 'remote_config'; // 远程配置键

  static const _screenPassword = '%s_screenPassword';
  static const _enabledBiometric = '%s_enabledBiometric';
  static const _chatFontSizeFactor = '%s_chatFontSizeFactor';
  static const _chatBackground = '%s_chatBackground_%s';
  static const _loginType = 'loginType';
  static const _meetingInProgress = '%_meetingInProgress';

  static const _rememberPassword = 'rememberPassword';
  static const _rememberedAccount = 'rememberedAccount';
  static const _rememberedPassword = 'rememberedPassword';
  static const _rememberedLoginType = 'rememberedLoginType';

  DataSp._();

  static init() async {
    await SpUtil().init();
  }

  static String getKey(String key, {String key2 = ""}) {
    return sprintf(key, [OpenIM.iMManager.userID, key2]);
  }

  static String? get imToken => getLoginCertificate()?.imToken;

  static String? get chatToken => getLoginCertificate()?.chatToken;

  static String? get orgId => getOrgId();

  static String? get userID => getLoginCertificate()?.userID;

  static Future<bool>? putLoginCertificate(LoginCertificate lc) {
    return SpUtil().putObject(_loginCertificate, lc);
  }

  static Future<bool>? putLoginAccount(Map map) {
    return SpUtil().putObject(_loginAccount, map);
  }

  static LoginCertificate? getLoginCertificate() {
    return SpUtil().getObj(_loginCertificate, (v) => LoginCertificate.fromJson(v.cast()));
  }

  static Future<bool>? removeLoginCertificate() {
    return SpUtil().remove(_loginCertificate);
  }

  static Map? getLoginAccount() {
    return SpUtil().getObject(_loginAccount);
  }

  static Future<bool>? putServerConfig(Map<String, String> config) {
    return SpUtil().putObject(_server, config);
  }

  static Map? getServerConfig() {
    return SpUtil().getObject(_server);
  }

  static Future<bool>? putServerIP(String ip) {
    return SpUtil().putString(ip, ip);
  }

  static String? getServerIP() {
    return SpUtil().getString(_ip);
  }

  /// 保存远程配置
  static Future<bool>? putRemoteConfig(Map<String, dynamic> config) {
    final jsonStr = jsonEncode(config);
    return SpUtil().putString(_remoteConfig, jsonStr);
  }

  /// 获取远程配置
  static Map<String, dynamic>? getRemoteConfig() {
    final jsonStr = SpUtil().getString(_remoteConfig);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      print('远程配置解析失败: $e');
      return null;
    }
  }

  static String getDeviceID() {
    String id = SpUtil().getString(_deviceID) ?? '';
    if (id.isEmpty) {
      id = const Uuid().v4();
      SpUtil().putString(_deviceID, id);
    }
    return id;
  }

  static Future<bool>? putOrgId(String orgId) {
    return SpUtil().putString("orgId", orgId);
  }

  static String getOrgId() {
    var orgId = SpUtil().getString('orgId');
    if (orgId == null || orgId.isEmpty) {
      orgId = "orgId";
    }
    return orgId;
  }

  static Future<bool>? putIgnoreVersion(String version) {
    return SpUtil().putString(_ignoreUpdate, version);
  }

  static String? getIgnoreVersion() {
    return SpUtil().getString(_ignoreUpdate);
  }

  static Future<bool>? putLanguage(int index) {
    return SpUtil().putInt(_language, index);
  }

  static int? getLanguage() {
    return SpUtil().getInt(_language);
  }

  static Future<bool>? putHaveReadUnHandleGroupApplication(List<String> idList) {
    return SpUtil().putStringList(getKey(_groupApplication), idList);
  }

  static Future<bool>? putHaveReadUnHandleFriendApplication(List<String> idList) {
    return SpUtil().putStringList(getKey(_friendApplication), idList);
  }

  static List<String>? getHaveReadUnHandleGroupApplication() {
    return SpUtil().getStringList(getKey(_groupApplication), defValue: []);
  }

  static List<String>? getHaveReadUnHandleFriendApplication() {
    return SpUtil().getStringList(getKey(_friendApplication), defValue: []);
  }

  static Future<bool>? putLockScreenPassword(String password) {
    return SpUtil().putString(getKey(_screenPassword), password);
  }

  static Future<bool>? clearLockScreenPassword() {
    return SpUtil().remove(getKey(_screenPassword));
  }

  static String? getLockScreenPassword() {
    return SpUtil().getString(getKey(_screenPassword), defValue: null);
  }

  static Future<bool>? openBiometric() {
    return SpUtil().putBool(getKey(_enabledBiometric), true);
  }

  static bool? isEnabledBiometric() {
    return SpUtil().getBool(getKey(_enabledBiometric), defValue: null);
  }

  static Future<bool>? closeBiometric() {
    return SpUtil().remove(getKey(_enabledBiometric));
  }

  static Future<bool>? putChatFontSizeFactor(double factor) {
    return SpUtil().putDouble(getKey(_chatFontSizeFactor), factor);
  }

  static double getChatFontSizeFactor() {
    return SpUtil().getDouble(
      getKey(_chatFontSizeFactor),
      defValue: Config.textScaleFactor,
    )!;
  }

  static Future<bool>? putChatBackground(String toUid, String path) {
    return SpUtil().putString(getKey(_chatBackground, key2: toUid), path);
  }

  static String? getChatBackground(String toUid) {
    return SpUtil().getString(getKey(_chatBackground, key2: toUid));
  }

  static Future<bool>? clearChatBackground(String toUid) {
    return SpUtil().remove(getKey(_chatBackground, key2: toUid));
  }

  static Future<bool>? putLoginType(int type) {
    return SpUtil().putInt(_loginType, type);
  }

  static int getLoginType() {
    return SpUtil().getInt(_loginType) ?? 0;
  }

  static Future<bool>? putMeetingInProgress(String meetingID) {
    return SpUtil().putString(getKey(_meetingInProgress), meetingID);
  }

  static String? getMeetingInProgress() {
    return SpUtil().getString(
      getKey(_meetingInProgress),
    );
  }

  static Future<bool>? removeMeetingInProgress() {
    return SpUtil().remove(getKey(_meetingInProgress));
  }

  static Future<bool>? putWalletStatus(bool status) {
    return SpUtil().putBool(getKey(_walletStatus), status);
  }

  static bool? getWalletStatus() {
    return SpUtil().getBool(getKey(_walletStatus), defValue: false);
  }

  /// 记住密码相关方法
  static Future<bool>? putRememberPassword(bool remember) {
    return SpUtil().putBool(_rememberPassword, remember);
  }

  static bool getRememberPassword() {
    return SpUtil().getBool(_rememberPassword) ?? false;
  }

  static Future<bool>? putRememberedAccount(String account) {
    return SpUtil().putString(_rememberedAccount, account);
  }

  static String? getRememberedAccount() {
    return SpUtil().getString(_rememberedAccount);
  }

  static Future<bool>? putRememberedPassword(String password) {
    // 对密码进行简单的编码存储（实际项目中应该使用更安全的加密方式）
    final encodedPassword = _encodePassword(password);
    return SpUtil().putString(_rememberedPassword, encodedPassword);
  }

  static String? getRememberedPassword() {
    final encodedPassword = SpUtil().getString(_rememberedPassword);
    if (encodedPassword != null && encodedPassword.isNotEmpty) {
      return _decodePassword(encodedPassword);
    }
    return null;
  }

  static Future<bool>? putRememberedLoginType(int loginType) {
    return SpUtil().putInt(_rememberedLoginType, loginType);
  }

  static int? getRememberedLoginType() {
    return SpUtil().getInt(_rememberedLoginType);
  }

  static Future<bool> clearRememberedCredentials() async {
    await SpUtil().remove(_rememberedAccount);
    await SpUtil().remove(_rememberedPassword);
    await SpUtil().remove(_rememberedLoginType);
    await SpUtil().putBool(_rememberPassword, false);
    return true;
  }

  /// 简单的密码编码（实际项目中应该使用更安全的加密方式）
  static String _encodePassword(String password) {
    // 这里使用简单的base64编码，实际项目中应该使用AES等更安全的加密方式
    final bytes = password.codeUnits;
    return bytes.map((byte) => (byte + 3).toString()).join(',');
  }

  /// 简单的密码解码
  static String _decodePassword(String encodedPassword) {
    try {
      final numbers = encodedPassword.split(',').map((s) => int.parse(s) - 3).toList();
      return String.fromCharCodes(numbers);
    } catch (e) {
      return '';
    }
  }
}
