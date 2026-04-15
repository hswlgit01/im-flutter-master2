import 'package:openim/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log_util.dart';
import 'rsa_service.dart';
import 'aes_util.dart';
import 'api_service.dart';
import 'dart:convert';

/// 安全管理器
/// 负责RSA密钥对生成和AES密钥管理
class SecurityManager {
  static const String TAG = "SecurityManager";
  
  // 密钥在SharedPreferences中的键名
  static const String _privateKeyKey = 'rsa_private_key';
  static const String _aesKeyKey = 'aes_encrypted_key';
  
  // 单例模式
  static final SecurityManager _instance = SecurityManager._internal();
  factory SecurityManager() => _instance;
  SecurityManager._internal();
  
  // 服务实例
  final _rsaService = RSAService();
  final _apiService = ApiService();
  
  bool _isInitialized = false;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 验证密码
  Future<bool> accountCompare(String password) async {
    try {
      if (!_isInitialized) {
        return false;
      }

      // 使用API服务验证密码
      final result = await _apiService.accountCompare(password);
      return result;
    } catch (e) {
      LogUtil.e(TAG, '密码验证异常: $e');
      return false;
    }
  }
  
  /// 登录后初始化安全服务
  /// 
  /// 1. 生成RSA密钥对
  /// 2. 将公钥发送到服务器
  /// 3. 接收并解密AES密钥
  /// 4. 安全存储私钥和AES密钥
  Future<bool> initAfterLogin() async {
    
    // 如果已经初始化，先重置
    if (_isInitialized) {
      await clearSecurityData();
    }
    
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // 生成RSA密钥对
        final publicKey = _rsaService.generateKeyPair();
        final privateKey = _rsaService.privateKeyPEM;
        
        if (privateKey == null) {
          retryCount++;
          continue;
        }
        
      
        
        // 将公钥发送到服务器
        final encryptedAesKey = await _apiService.setupUserKeys(publicKey);
        if (encryptedAesKey == null) {
          retryCount++;
          continue;
        }
        
        // 使用RSA私钥解密AES密钥
        final aesKey = _rsaService.decrypt(encryptedAesKey);
        if (aesKey == null || aesKey.isEmpty) {
          retryCount++;
          continue;
        }
        
        
        // 安全存储私钥和AES密钥
        await _saveKeysToStorage(privateKey, aesKey);
        
        // 初始化AES工具
        await AESUtil().initWithKey(aesKey);
        
        _isInitialized = true;
        return true;
      } catch (e) {
        LogUtil.e(TAG, '安全服务初始化失败 (尝试 ${retryCount + 1}/$maxRetries): $e');
        retryCount++;
        
        if (retryCount >= maxRetries) {
          LogUtil.e(TAG, '安全服务初始化失败，已达到最大重试次数');
          return false;
        }
        
        // 等待一段时间后重试
        await Future.delayed(Duration(seconds: 1));
      }
    }
    
    return false;
  }
  
  /// 检查并恢复密钥（应用启动时调用）
  Future<bool> checkAndRestoreKeys() async {
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final privateKey = prefs.getString(_privateKeyKey);
      final aesKey = prefs.getString(_aesKeyKey);
      
      if (privateKey == null || aesKey == null) {
        return false;
      }
      
      // 恢复RSA私钥
      _rsaService.initRSA(
        publicKey: '', // 客户端只需要私钥来签名和解密
        privateKey: privateKey,
      );
      
      // 初始化AES工具
      await AESUtil().initWithKey(aesKey);
      
      _isInitialized = true;
      return true;
    } catch (e) {
      LogUtil.e(TAG, '恢复密钥失败: $e');
      return false;
    }
  }
  
  /// 安全存储密钥
  Future<void> _saveKeysToStorage(String privateKey, String aesKey) async {
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_privateKeyKey, privateKey);
      await prefs.setString(_aesKeyKey, aesKey);
    } catch (e) {
      LogUtil.e(TAG, '存储密钥失败: $e');
      throw Exception('存储密钥失败: $e');
    }
  }
  
  /// 使用RSA私钥签名数据
  Future<String> signData(String data) async {
    if (!_isInitialized) {
      // 自动尝试初始化
      final initialized = await ensureInitialized();
      if (!initialized) {
        throw Exception('安全服务未初始化');
      }
    }
    
    try {
      return _rsaService.sign(data);
    } catch (e) {
      LogUtil.e(TAG, '签名失败: $e');
      throw Exception('签名失败: $e');
    }
  }
  
  /// 使用AES加密数据
  Future<String> encryptData(String data) async {
    if (!_isInitialized) {
      // 自动尝试初始化
      final initialized = await ensureInitialized();
      if (!initialized) {
        throw Exception('安全服务未初始化');
      }
    }
    
    try {
      return AESUtil().encrypt(data);
    } catch (e) {
      LogUtil.e(TAG, 'AES加密失败: $e');
      throw Exception('AES加密失败: $e');
    }
  }
  
  /// 使用AES解密数据
  Future<String> decryptData(String encryptedData) async {
    if (!_isInitialized) {
      // 自动尝试初始化
      final initialized = await ensureInitialized();
      if (!initialized) {
        throw Exception('安全服务未初始化');
      }
    }
    
    try {
      return AESUtil().decrypt(encryptedData);
    } catch (e) {
      LogUtil.e(TAG, 'AES解密失败: $e');
      throw Exception('AES解密失败: $e');
    }
  }
  
  /// 使用AES加密JSON数据
  Future<String> encryptJson(Map<String, dynamic> jsonData) async {
    if (!_isInitialized) {
      // 自动尝试初始化
      final initialized = await ensureInitialized();
      if (!initialized) {
        throw Exception('安全服务未初始化');
      }
    }
    
    try {
      // 将JSON转换为字符串
      final jsonString = jsonEncode(jsonData);
      // 使用AES加密
      return AESUtil().encrypt(jsonString);
    } catch (e) {
      LogUtil.e(TAG, 'JSON加密失败: $e');
      throw Exception('JSON加密失败: $e');
    }
  }
  
  /// 使用AES解密JSON数据
  Future<Map<String, dynamic>> decryptJson(String encryptedData) async {
    if (!_isInitialized) {
      // 自动尝试初始化
      final initialized = await ensureInitialized();
      if (!initialized) {
        throw Exception('安全服务未初始化');
      }
    }
    
    try {
      // 使用AES解密
      final decryptedString = AESUtil().decrypt(encryptedData);
      // 将字符串转换回JSON
      return jsonDecode(decryptedString) as Map<String, dynamic>;
    } catch (e) {
      LogUtil.e(TAG, 'JSON解密失败: $e');
      throw Exception('JSON解密失败: $e');
    }
  }
  
  /// 清除安全数据（登出时调用）
  Future<void> clearSecurityData() async {
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_privateKeyKey);
      await prefs.remove(_aesKeyKey);
      
      _rsaService.reset();
      await AESUtil().clearKey();
      
      _isInitialized = false;
    } catch (e) {
      LogUtil.e(TAG, '清除安全数据失败: $e');
    }
  }
  
  /// 确保安全服务已初始化
  /// 如果未初始化，会尝试从本地恢复密钥，或者重新初始化
  /// 返回初始化是否成功
  Future<bool> ensureInitialized() async {
    try {
      // 如果已经初始化，直接返回成功
      if (_isInitialized) {
        return true;
      }
      
      // 尝试从本地恢复密钥
      final restored = await checkAndRestoreKeys();
      if (restored) {
        return true;
      }
      
      // 如果恢复失败，尝试重新初始化
      final result = await initAfterLogin();
      return result;
    } catch (e) {
      LogUtil.e(TAG, '确保安全服务初始化失败: $e');
      return false;
    }
  }
} 