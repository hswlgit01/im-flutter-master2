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

