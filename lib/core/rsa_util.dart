import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openim_common/openim_common.dart' hide DataSp;
import '../utils/log_util.dart';
import 'rsa_service.dart';

/// RSA工具类
/// 负责RSA服务的初始化和密钥管理
class RSAUtil {
  static const String TAG = "RSAUtil";
  
  // 密钥在SharedPreferences中的键名
  static const String _publicKeyKey = 'rsa_public_key';
  
  // RSA服务实例
  static final _rsaService = RSAService();
  
  /// 生成并打印RSA密钥对
  /// 仅用于测试和开发目的
  static String generateAndPrintKeyPair() {
    try {
      final publicKey = _rsaService.generateKeyPair();
      return publicKey;
    } catch (e) {
      LogUtil.e(TAG, '生成RSA密钥对失败', e);
      throw Exception('生成RSA密钥对失败: $e');
    }
  }
  
  /// 对测试文本进行签名并打印结果
  /// 仅用于测试和开发目的
  static String signAndPrintDemo(String text) {
    try {
      // 确保已生成密钥对（如果尚未初始化）
      if (!_rsaService.isInitialized) {
        generateAndPrintKeyPair();
      }
      
      // 进行签名
      final signature = _rsaService.sign(text);
      
  
      return signature;
    } catch (e) {
      LogUtil.e(TAG, '签名失败', e);
      throw Exception('签名失败: $e');
    }
  }
  
  /// 初始化RSA服务（登录后调用）
  /// 
  /// 从后端接口获取公钥，然后初始化RSA服务
  /// [publicKey] - 从后端接口获取的公钥
  /// 返回初始化是否成功
  static Future<bool> initRSAWithPublicKey(String publicKey) async {
    
    try {
      // 保存公钥到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_publicKeyKey, publicKey);
      
      // 初始化RSA服务
      _rsaService.initRSA(
        publicKey: publicKey,
        privateKey: null, // 客户端不需要私钥
      );
      
      return true;
    } catch (e) {
      LogUtil.e(TAG, 'RSA初始化失败', e);
      return false;
    }
  }
  
  /// 检查RSA服务是否已初始化
  /// 
  /// 如果服务未初始化，会尝试从SharedPreferences中读取之前保存的公钥
  /// 返回RSA服务是否已初始化
  static Future<bool> checkAndInitRSA() async {
    if (_rsaService.isInitialized) {
      return true;
    }
    
    
    try {
      // 尝试从SharedPreferences中读取公钥
      final prefs = await SharedPreferences.getInstance();
      final publicKey = prefs.getString(_publicKeyKey);
      
      if (publicKey != null && publicKey.isNotEmpty) {
        _rsaService.initRSA(
          publicKey: publicKey,
          privateKey: null,
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      LogUtil.e(TAG, '恢复RSA公钥失败', e);
      return false;
    }
  }
  
  /// 使用RSA加密数据
  /// 
  /// 如果RSA服务未初始化，会抛出异常
  /// [data] - 要加密的数据
  /// 返回加密后的数据
  static String encrypt(String data) {
    if (!_rsaService.isInitialized) {
      throw Exception('RSA服务未初始化，请先调用initRSAWithPublicKey');
    }
    
    try {
      return _rsaService.encrypt(data);
    } catch (e) {
      throw Exception('数据加密失败: $e');
    }
  }
  
  /// 清除存储的RSA公钥（登出时调用）
  static Future<void> clearKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_publicKeyKey);
    _rsaService.reset();
  }
} 