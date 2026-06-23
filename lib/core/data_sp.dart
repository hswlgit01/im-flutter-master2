import 'package:shared_preferences/shared_preferences.dart';

class DataSp {
  static SharedPreferences? _prefs;
  static bool _isInitialized = false;
  
  static Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }
  
  static const String _keyWalletStatus = 'wallet_status';
  static const String _keyLanguage = 'language';
  static const String _biometricEnabled = 'biometric_enabled';
  // dawn 2026-06-23 敏感词架构改：登录拉取后持久化词表+版本号，发消息直接读本地缓存(0延迟)。
  static const String _keySensitiveWords = 'sensitive_words';
  static const String _keySensitiveWordsVersion = 'sensitive_words_version';

  static List<String> getSensitiveWords() {
    if (!_isInitialized) {
      init();
    }
    return _prefs?.getStringList(_keySensitiveWords) ?? <String>[];
  }

  static Future<void> putSensitiveWords(List<String> words) async {
    if (!_isInitialized) {
      await init();
    }
    await _prefs?.setStringList(_keySensitiveWords, words);
  }

  static String getSensitiveWordsVersion() {
    if (!_isInitialized) {
      init();
    }
    return _prefs?.getString(_keySensitiveWordsVersion) ?? '';
  }

  static Future<void> putSensitiveWordsVersion(String version) async {
    if (!_isInitialized) {
      await init();
    }
    await _prefs?.setString(_keySensitiveWordsVersion, version);
  }
  
  static Future<bool> getWalletStatus() async {
    if (!_isInitialized) {
      await init();
    }
    return _prefs?.getBool(_keyWalletStatus) ?? false;
  }
  
  static Future<void> putWalletStatus(bool status) async {
    if (!_isInitialized) {
      await init();
    }
    await _prefs?.setBool(_keyWalletStatus, status);
  }

  static Future<int?> getLanguage() async {
    if (!_isInitialized) {
      await init();
    }
    return _prefs?.getInt(_keyLanguage);
  }

  static bool? getBiometricEnabled() {
    if (!_isInitialized) {
      init();
    }
    return _prefs?.getBool(_biometricEnabled);
  }

  static Future<bool> setBiometricEnabled(bool value) async {
    if (!_isInitialized) {
      await init();
    }
    return await _prefs?.setBool(_biometricEnabled, value) ?? false;
  }
} 

