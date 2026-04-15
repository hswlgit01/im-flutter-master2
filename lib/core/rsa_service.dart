import 'package:encrypt/encrypt.dart';
import 'package:openim/utils/logger.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:pointycastle/api.dart' show KeyParameter, ParametersWithRandom;
import 'package:basic_utils/basic_utils.dart';  // 添加这个库来处理PEM编码

/// RSA 加密服务
/// 单例模式实现
class RSAService {
  static final RSAService _instance = RSAService._internal();
  factory RSAService() => _instance;
  RSAService._internal();

  late Encrypter _encrypter;
  late RSAPublicKey _publicKey;
  RSAPrivateKey? _privateKey;
  bool _isInitialized = false;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 生成RSA密钥对
  /// 返回PEM格式的公钥字符串
  String generateKeyPair() {
    try {
      if (_isInitialized) {
        // 如果已经初始化，重置状态
        reset();
      }

      // 创建随机数生成器
      final secureRandom = FortunaRandom();
      final random = Random.secure();
      final seed = List<int>.generate(32, (_) => random.nextInt(256));
      secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));

      // 创建RSA密钥生成器
      final keyGen = RSAKeyGenerator()
        ..init(ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
            secureRandom));

      // 生成密钥对
      final pair = keyGen.generateKeyPair();
      _publicKey = pair.publicKey as RSAPublicKey;
      _privateKey = pair.privateKey as RSAPrivateKey;

      // 生成标准PEM格式密钥
      final publicKeyPem = CryptoUtils.encodeRSAPublicKeyToPem(_publicKey);
      final privateKeyPem = _privateKey != null ? CryptoUtils.encodeRSAPrivateKeyToPem(_privateKey!) : "无私钥";

    
      // 初始化加密器 - 使用 PKCS#1 v1.5 填充（与服务端保持一致）
      _encrypter = Encrypter(RSA(
        publicKey: _publicKey,
        privateKey: _privateKey,
        encoding: RSAEncoding.PKCS1,
      ));

      _isInitialized = true;

      // 返回PEM格式的公钥
      return publicKeyPem;
    } catch (e) {
      _isInitialized = false;
      ILogger.e('生成RSA密钥对失败: $e');
      throw Exception('生成RSA密钥对失败: $e');
    }
  }

  /// 使用公钥加密
  /// [text] 要加密的文本
  /// 返回 base64 编码的加密结果
  String encrypt(String text) {
    if (!_isInitialized) {
      throw Exception('RSA 未初始化');
    }
    try {
      final encrypted = _encrypter.encrypt(text);
      return encrypted.base64;
    } catch (e) {
      throw Exception('RSA 加密失败: $e');
    }
  }

  /// 使用私钥签名
  /// [text] 要签名的文本
  /// 返回 base64 编码的签名结果
  String sign(String text) {
    if (!_isInitialized || _privateKey == null) {
      throw Exception('RSA 未初始化或没有私钥');
    }
    try {
      // 使用 RSA 算法进行签名，需要单独处理
      final signature = CryptoUtils.rsaSign(
        _privateKey!,
        Uint8List.fromList(utf8.encode(text))
      );
      return base64.encode(signature);
    } catch (e) {
      throw Exception('RSA 签名失败: $e');
    }
  }

  /// 验证签名
  /// [text] 原始文本
  /// [signature] base64编码的签名
  /// 返回是否验证成功
  bool verify(String text, String signature) {
    if (!_isInitialized) {
      throw Exception('RSA 未初始化');
    }
    try {
      final signatureBytes = base64.decode(signature);
      return CryptoUtils.rsaVerify(
        _publicKey,
        Uint8List.fromList(utf8.encode(text)),
        signatureBytes,
        algorithm: 'SHA-256/RSA'
      );
    } catch (e) {
      throw Exception('RSA 验证签名失败: $e');
    }
  }

  /// 使用私钥解密
  /// [encryptedText] base64 编码的加密文本
  /// 返回解密后的文本
  String decrypt(String encryptedText) {
    if (!_isInitialized || _privateKey == null) {
      throw Exception('RSA 未初始化或没有私钥');
    }
    try {
      // 使用 PKCS1 填充模式进行解密（与服务端的 EncryptPKCS1v15 匹配）
      final encrypter = Encrypter(RSA(
        publicKey: _publicKey,
        privateKey: _privateKey,
        encoding: RSAEncoding.PKCS1, // 明确指定 PKCS#1 v1.5 填充
      ));

      final encrypted = Encrypted.fromBase64(encryptedText);
      final decrypted = encrypter.decrypt(encrypted);

      return decrypted;
    } catch (e) {
      ILogger.e('RSA 解密失败: $e');
      throw Exception('RSA 解密失败: $e');
    }
  }

  /// 初始化 RSA，使用标准PEM格式密钥
  /// [publicKey] 公钥
  /// [privateKey] 私钥（可选）
  void initRSA({
    required String publicKey,
    String? privateKey,
  }) {
    try {
      // 使用标准库解析PEM密钥
      final publicKeyObj = CryptoUtils.rsaPublicKeyFromPem(publicKey);
      final privateKeyObj = privateKey != null 
          ? CryptoUtils.rsaPrivateKeyFromPem(privateKey)
          : null;

      _publicKey = publicKeyObj;
      _privateKey = privateKeyObj;
      _encrypter = Encrypter(RSA(
        publicKey: publicKeyObj,
        privateKey: privateKeyObj,
        encoding: RSAEncoding.PKCS1,
      ));

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      throw Exception('RSA 初始化失败: $e');
    }
  }

  /// 重置RSA服务
  void reset() {
    _isInitialized = false;
    _privateKey = null;
  }

  // 获取公钥PEM格式
  String? get publicKeyPEM {
    if (!_isInitialized) return null;
    return CryptoUtils.encodeRSAPublicKeyToPem(_publicKey);
  }

  // 获取私钥PEM格式
  String? get privateKeyPEM {
    if (!_isInitialized || _privateKey == null) return null;
    return CryptoUtils.encodeRSAPrivateKeyToPem(_privateKey!);
  }
}