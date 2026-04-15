import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log_util.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:pointycastle/export.dart' as pc;

/// AES加密工具类
/// 实现AES-256-GCM模式加密/解密，与Go端完全兼容
class AESUtil {
  static const String TAG = "AESUtil";
  static const String _keyKey = 'aes_key';
  
  // 单例模式
  static final AESUtil _instance = AESUtil._internal();
  factory AESUtil() => _instance;
  AESUtil._internal();

  // 将late final改为可变的字段
  Uint8List? _key;
  bool _isInitialized = false;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized && _key != null;
  
  /// 初始化AES加密器
  /// 
  /// 如果本地存储有密钥，则使用存储的密钥
  /// 否则生成新的密钥并存储
  Future<void> init() async {
    if (_isInitialized && _key != null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String? keyString = prefs.getString(_keyKey);
      
      if (keyString == null) {
        // 生成新的密钥
        _key = _generateKey();
        keyString = base64.encode(_key!);
        await prefs.setString(_keyKey, keyString);
      } else {
        // 使用存储的密钥
        _key = base64.decode(keyString);
      }
      
      _isInitialized = true;
    } catch (e) {
      LogUtil.e(TAG, 'AES-256-GCM加密器初始化失败: $e');
      rethrow;
    }
  }
  
  /// 使用指定的密钥初始化AES加密器
  /// 
  /// [keyString] Base64编码的密钥字符串
  Future<void> initWithKey(String keyString) async {
    try {
      // 如果已经初始化，先重置
      if (_isInitialized) {
        await clearKey();
      }
      
      // 解码并验证密钥
      _key = base64.decode(keyString);
      if (_key!.length != 32) {
        throw Exception('密钥长度错误，应为32字节');
      }
      
      _isInitialized = true;
    } catch (e) {
      LogUtil.e(TAG, '使用提供的密钥初始化AES-256-GCM加密器失败: $e');
      rethrow;
    }
  }

  /// 加密数据
  /// 
  /// [data] - 要加密的数据
  /// 返回加密后的base64字符串
  String encrypt(String data) {
    if (!isInitialized) {
      throw Exception('AES-256-GCM加密器未初始化');
    }
    
    try {
      // 将输入数据转换为UTF-8字节
      final plainBytes = utf8.encode(data);
      
      // 生成nonce
      final nonce = _generateNonce(12);
      
      // 创建GCM参数
      final params = pc.ParametersWithIV(
        pc.KeyParameter(_key!),
        Uint8List.fromList(nonce)
      );
      
      // 创建GCM加密器
      final cipher = pc.GCMBlockCipher(pc.AESEngine())
        ..init(true, params);
      
      // 加密
      final cipherText = cipher.process(Uint8List.fromList(plainBytes));
      
      // 组合nonce和密文
      final result = Uint8List(nonce.length + cipherText.length);
      result.setRange(0, nonce.length, nonce);
      result.setRange(nonce.length, nonce.length + cipherText.length, cipherText);
      
      // 返回base64编码的结果
      return base64.encode(result);
    } catch (e) {
      LogUtil.e(TAG, '数据加密失败: $e');
      rethrow;
    }
  }

  /// 解密数据
  /// 
  /// [encryptedData] - 加密后的base64字符串
  /// 返回解密后的原始数据
  String decrypt(String encryptedData) {
    if (!isInitialized) {
      throw Exception('AES-256-GCM加密器未初始化');
    }
    
    try {
      // 解码base64数据
      final cipherBytes = base64.decode(encryptedData);
      if (cipherBytes.length < 12) {
        throw Exception('密文太短，无法提取nonce');
      }
      
      // 提取nonce和密文
      final nonce = cipherBytes.sublist(0, 12);
      final actualCipherText = cipherBytes.sublist(12);
      
      // 创建GCM参数
      final params = pc.ParametersWithIV(
        pc.KeyParameter(_key!),
        Uint8List.fromList(nonce)
      );
      
      // 创建GCM解密器
      final cipher = pc.GCMBlockCipher(pc.AESEngine())
        ..init(false, params);
      
      // 解密
      final decryptedBytes = cipher.process(Uint8List.fromList(actualCipherText));
      
      // 返回UTF-8解码的结果
      return utf8.decode(decryptedBytes);
    } catch (e) {
      LogUtil.e(TAG, '数据解密失败: $e');
      rethrow;
    }
  }

  /// 清除存储的密钥（登出时调用）
  Future<void> clearKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyKey);
      _isInitialized = false;
      _key = null; // 清除密钥
    } catch (e) {
      LogUtil.e(TAG, '清除AES密钥失败: $e');
    }
  }

  /// 生成256位AES密钥
  Uint8List _generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  /// 生成指定长度的随机nonce
  List<int> _generateNonce(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}


// // 初始化（在应用启动时调用）
// await AESUtil().init();

// // 加密数据
// String encrypted = AESUtil().encrypt("要加密的数据");

// // 解密数据
// String decrypted = AESUtil().decrypt(encrypted);

// // 登出时清除密钥
// await AESUtil().clearKey();