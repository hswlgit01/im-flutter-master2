import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';
import 'dart:convert';

import '../pages/wallet/widgets/password_verify_dialog.dart';
import '../utils/log_util.dart';
import './security_manager.dart';
import 'api_service.dart';
import 'package:openim_common/src/widgets/loading_view.dart';

/// 安全服务类
/// 用于处理身份验证和加密操作
class SecurityService {
  static const String TAG = "SecurityService";
  
  // 单例模式
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal() {
    LogUtil.i(TAG, '安全服务初始化');
  }

  // 生物识别认证工具
  final _auth = LocalAuthentication();
  
  // 安全管理器
  final _securityManager = SecurityManager();

  bool _useBiometric = false;

  void setUseBiometric(bool value) {
    _useBiometric = value;
  }


  /// 检查是否需要重新初始化
  static Future<bool> needsReinitialization() async {
    final instance = SecurityService();
    return !await instance._securityManager.isInitialized;
  }

  /// 初始化RSA加密服务（登录成功后调用）
  /// 
  /// [publicKey] - 从服务器获取的RSA公钥
  /// 返回初始化是否成功
  Future<bool> initRSA(String publicKey) async {
    
    try {
      // 先检查是否已初始化
      if (await _securityManager.isInitialized) {
        return true;
      }

      // 尝试从本地恢复密钥
      final restored = await _securityManager.checkAndRestoreKeys();
      if (restored) {
        return true;
      }

      // 如果恢复失败，重新初始化
      final success = await _securityManager.initAfterLogin();
      if (!success) {
        return false;
      }

      return true;
    } catch (e) {
      LogUtil.e(TAG, '安全服务初始化异常: $e');
      return false;
    }
  }

  /// 验证RSA服务是否已初始化
  /// 
  /// 如果未初始化，会尝试从本地存储恢复
  /// 返回RSA服务是否可用
  Future<bool> isRSAAvailable() async {
    return _securityManager.isInitialized;
  }

  /// 验证并加密
  /// 
  /// 如果有生物识别功能则调用生物识别，生物识别成功后使用RSA私钥对原始数据进行签名再使用AES对复合结构加密
  /// 如果生物识别没有或失败，弹框输入支付密码，然后使用AES对整个JSON加密
  /// 
  /// [data] - 要加密的数据对象
  /// [biometricReason] - 生物识别验证原因提示文字
  /// [passwordTitle] - 密码验证对话框标题
  /// [verifyPassword] - 自定义密码验证函数，默认返回true
  /// [onFailure] - 验证失败回调
  Future<String?> verifyAndEncrypt({
    required Map<String, dynamic> data,
    String? biometricReason,
    String? passwordTitle,
    Future<bool> Function(String)? verifyPassword,
    Function()? onFailure,
  }) async {
    try {
      // 验证用户身份
      bool authenticated = false;
      bool isBiometric = false;
      String? password;
      
      // 检查是否支持生物识别
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      ILogger.d(_useBiometric);
      // 尝试生物识别
      if (_useBiometric && canCheckBiometrics && isDeviceSupported) {
        try {
          authenticated = await _auth.authenticate(
            localizedReason: biometricReason ?? StrRes.verifyIdentity,
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: true,
            ),
          );
          if (authenticated) {
            isBiometric = true;
          }
        } catch (e) {
          LogUtil.e(TAG, '生物识别验证失败: $e');
          // 降级到密码验证
        }
      }

      // 如果生物识别失败，尝试密码验证
      if (!authenticated) {
        final result = await Get.dialog<PasswordVeifyBackType>(
          PasswordVerifyDialog(
            title: passwordTitle ?? StrRes.enterPaymentPassword,
            onConfirm: (inputPassword) async {
              password = inputPassword;
              if (verifyPassword != null) {
                return verifyPassword(inputPassword);
              }
              return true;
            },
          ),
          barrierDismissible: false,
        );
        
        if (result == PasswordVeifyBackType.success) {
          authenticated = true;
        }
      }

      // 验证成功后加密数据
      if (authenticated) {
        if (isBiometric) {
          // 生物识别成功：签名 + AES加密
          final dataString = jsonEncode(data);
          final signature = await _securityManager.signData(dataString);
          if (signature == null) {
            throw Exception('签名失败');
          }

          // 构建复合结构
          final compositeData = {
            'data': data,
            'signature': signature,
          };

          // 使用AES加密复合结构
          final encryptedData = await _securityManager.encryptJson(compositeData);
          
          // 构建最终返回结果
          final result = {
            'need_rsa_verify': true,
            'encrypted_data': encryptedData,
          };
          
          return jsonEncode(result);
        } else {
          // 密码验证：直接AES加密
          final jsonData = {
            ...data,
            'pay_password': password,
          };
          final encryptedData = await _securityManager.encryptJson(jsonData);
          
          // 构建最终返回结果
          final result = {
            'need_rsa_verify': false,
            'encrypted_data': encryptedData,
          };
          
          return jsonEncode(result);
        }
      } else {
        onFailure?.call();
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '验证和加密失败: $e');
      onFailure?.call();
      return null;
    }
  }
  
  /// 签名数据
  /// [data] - 要签名的数据
  /// 返回签名后的字符串
  Future<String?> signData(String data) async {
    try {
      if (!_securityManager.isInitialized) {
        return null;
      }
      
      return _securityManager.signData(data);
    } catch (e) {
      LogUtil.e(TAG, '签名失败: $e');
      return null;
    }
  }

  /// 清除安全服务数据
  Future<void> clearSecurityData() async {
    await _securityManager.clearSecurityData();
  }

  /// 验证身份
  /// 
  /// [passwordTitle] - 密码验证对话框标题
  /// [verifyPassword] - 自定义密码验证函数，默认返回true
  /// [onFailure] - 验证失败回调
  /// [onPasswordInput] - 密码输入回调
  Future<bool> verifyIdentity({
    String passwordTitle = '请输入登录密码',
    Future<bool> Function(String)? verifyPassword,
    Function(String)? onFailure,
    Function(String)? onPasswordInput,
  }) async {
    try {
      bool authenticated = false;
      PasswordVeifyBackType? pvResult;
      
      // 使用密码验证
      if (!authenticated) {
        pvResult = await Get.dialog<PasswordVeifyBackType>(
          PasswordVerifyDialog(
            title: passwordTitle,
            onConfirm: (password) async {
              try {
                // 调用accountCompare接口验证密码
                final success = await LoadingView.singleton.wrap(
                  asyncFunction: () => _securityManager.accountCompare(password),
                );
                if (!success) {
                  IMViews.showToast('密码错误');
                  return false;
                }
                
                // 如果有自定义验证函数，也执行验证
                if (verifyPassword != null) {
                  return verifyPassword(password);
                }
                
                // 回调输入的密码
                onPasswordInput?.call(password);
                return true;
              } catch (e) {
                LogUtil.e(TAG, '密码验证失败: $e');
                IMViews.showToast('密码验证失败');
                return false;
              }
            },
          ),
          barrierDismissible: false,
        );
        
        authenticated = pvResult == PasswordVeifyBackType.success;
      }
      
      if (!authenticated && onFailure != null && pvResult != PasswordVeifyBackType.cancel) {
        onFailure('验证失败');
      }
      
      return authenticated;
    } catch (e) {
      LogUtil.e(TAG, '验证身份失败: $e');
      onFailure?.call('验证过程发生错误: $e');
      return false;
    }
  }

  /// 使用AES加密JSON数据
  Future<String> encryptJson(Map<String, dynamic> jsonData) async {
    if (!_securityManager.isInitialized) {
      throw Exception('安全服务未初始化');
    }
    
    try {
      // 将JSON转换为字符串
      final jsonString = jsonEncode(jsonData);
      // 使用AES加密
      return _securityManager.encryptJson(jsonData);
    } catch (e) {
      LogUtil.e(TAG, 'JSON加密失败: $e');
      throw Exception('JSON加密失败: $e');
    }
  }
  
  /// 使用AES解密JSON数据
  Future<Map<String, dynamic>> decryptJson(String encryptedData) async {
    if (!_securityManager.isInitialized) {
      throw Exception('安全服务未初始化');
    }
    
    try {
      // 使用AES解密
      return _securityManager.decryptJson(encryptedData);
    } catch (e) {
      LogUtil.e(TAG, 'JSON解密失败: $e');
      throw Exception('JSON解密失败: $e');
    }
  }
} 