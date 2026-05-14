import 'package:openim/utils/logger.dart';
import 'package:openim_common/openim_common.dart';
import 'package:uuid/uuid.dart';
import '../utils/log_util.dart';
import 'package:dio/dio.dart';

/// API服务类
/// 提供与后端API交互的方法
class ApiService {
  static const String TAG = "ApiService";

  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Dio实例

  /// 检查 chatToken 是否有效
  bool _checkChatToken() {
    final chatToken = DataSp.chatToken;
    if (chatToken == null || chatToken.isEmpty) {
      return false;
    }
    return true;
  }

  /// 获取RSA公钥
  ///
  /// 从服务器获取用于加密的RSA公钥
  /// 返回公钥字符串，失败时返回null
  Future<String?> getRSAPublicKey() async {
    try {
      var key = await getMockRSAPublicKey();
      return key;
    } catch (e) {
      LogUtil.e(TAG, '获取RSA公钥失败：$e');
      return null;
    }
  }

  /// 获取RSA公钥（模拟）
  ///
  /// 当服务器接口未实现时，返回一个硬编码的公钥用于开发测试
  /// 实际生产环境中应该通过真实接口获取
  Future<String> getMockRSAPublicKey() async {
    // 模拟网络延迟
    await Future.delayed(Duration(milliseconds: 300));

    // 返回一个硬编码的示例公钥
    return '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5Jbp/I9SdFBfd1e4aC+t7prpRQD+b8Imig8NIXvU3n/k8XB1Rf6PWtQUsBe7OqK7w+A7Cbt7zrc0ktZAGwvFXfW3/66ntqh7uhWgXkhfvG0O0Sck2lspKCCVydMUhQejmYeJph6mMvhHs9UdkFaCGVcES3wjz9Kt4L/c1YZytJwXeAUlOOXrYozzFG1FkkIBsJTenFh3zunnGV6HayMUgtEkZ1Dfkx8upMvilLdBkKut1KPkF1XyGX9ae7j5Ev66zh8BhVEFHFWXM/YjGzYO0lPypdE7sn1rlwPxAqBsJIAoQT28rXAL7q5T//xxIvqT1gGhO9g+kHCuhw8Au95YgwIDAQAB
-----END PUBLIC KEY-----''';
  }

  /// 检查钱包是否开通
  ///
  /// 调用后端接口检查当前用户是否已开通钱包
  /// 返回是否开通，失败时返回false
  Future<bool> checkWalletExist() async {
    try {
      if (!_checkChatToken()) return false;

      final data = await HttpUtil.get(
        Urls.checkWalletExist,
        options: Apis.chatTokenOptions,
      );

      final exist = data ?? false;
      return exist;
    } catch (e) {
      LogUtil.e(TAG, '检查钱包是否开通失败: $e');
      return false;
    }
  }

  /// 触发补偿金初始化
  ///
  /// 调用后端接口为当前钱包触发补偿金初始化
  /// 这可用于为在补偿金系统启用前创建的钱包补发补偿金
  /// 返回是否成功触发，失败时返回false
  ///
  /// 注意：此方法仅应在钱包页面首次加载时调用一次，避免重复触发
  Future<bool> triggerCompensationInit() async {
    try {
      if (!_checkChatToken()) return false;

      // 使用专门的补偿金初始化API端点
      final String endpoint = Urls.compensationInit;

      LogUtil.i(TAG, '尝试触发补偿金初始化');

      // 创建Dio实例
      final dio = Dio();
      dio.options.headers = Apis.chatTokenOptions.headers;

      // 直接使用Dio发送请求
      final response = await dio.post(endpoint);

      // 检查HTTP状态码，如果是200，认为调用成功
      final success = response.statusCode == 200;

      // 解析具体的错误码
      final errCode = response.data is Map<String, dynamic> ? response.data['errCode'] : null;

      LogUtil.i(TAG, '补偿金初始化结果: HTTP状态码=$success, 错误码=$errCode');

      // 只要HTTP状态码是200且API错误码为0，就认为成功
      return success && (errCode == 0);
    } catch (e) {
      LogUtil.e(TAG, '触发补偿金初始化失败: $e');
      return false;
    }
  }

  /// 创建钱包
  ///
  /// 调用后端接口创建钱包
  /// 返回包含创建结果和说明文本的Map：
  /// - success: 是否创建成功
  /// - noticeText: 钱包开通说明文本 (补偿金说明)
  Future<Map<String, dynamic>> createWallet(String encryptedPassword) async {
    try {
      if (!_checkChatToken()) return {'success': false, 'noticeText': ''};

      final data = await HttpUtil.post(
        Urls.createWallet,
        data: {'encrypted_data': encryptedPassword, 'need_rsa_verify': false},
        options: Apis.chatTokenOptions,
      );

      // 记录完整响应，便于排查问题
      LogUtil.i(TAG, '钱包创建API响应: $data');

      // API响应现在包含一个嵌套结构，根据日志显示
      // wallet_info 字段包含钱包信息，notice_text 字段包含说明文本
      if (data == null) {
        return {'success': false, 'noticeText': ''};
      }

      // 检查wallet_info字段存在
      final walletInfo = data['wallet_info'];
      final noticeText = data['notice_text'] ?? '';

      if (walletInfo == null || walletInfo['id'] == null) {
        LogUtil.e(TAG, '创建钱包失败: 返回的钱包信息无效');
        return {'success': false, 'noticeText': ''};
      }

      // 记录成功创建的日志，包括提取的通知文本
      LogUtil.i(TAG, '钱包创建成功，钱包ID: ${walletInfo['id']}');
      LogUtil.i(TAG, '钱包开通说明文本: $noticeText');

      return {'success': true, 'noticeText': noticeText};
    } catch (e) {
      LogUtil.e(TAG, '创建钱包失败: $e');
      return {'success': false, 'noticeText': ''};
    }
  }

  /// 验证登陆密码
  Future<bool> accountCompare(String password) async {
    try {
      if (!_checkChatToken()) return false;

      final result = await HttpUtil.post(
        Urls.accountCompare,
        data: {'pwd': IMUtils.generateMD5(password)},
        options: Apis.chatTokenOptions,
      );

      if (result == null) {
        return false;
      }

      return result as bool;
    } catch (e) {
      LogUtil.e(TAG, '验证登陆密码失败: $e');
      return false;
    }
  }


  /// 根据组织查询钱包余额
  Future<BalanceData?> walletBalanceByOrg(String orgId) async {
    try {
      if (!_checkChatToken()) return null;

      final data = await HttpUtil.get(
        Urls.walletBalanceByOrg,
        options: Apis.chatTokenOptions,
        queryParameters: {
          'org_id': orgId,
        }
      );

      final walletData = data;
      if (walletData == null) {
        return null;
      }

      return BalanceData.fromJson(walletData);
    } catch (e) {
      LogUtil.e(TAG, '查询钱包余额失败: $e');
      return null;
    }
  }

  /// 查询汇率
  Future<ExchageRateInfo?> getExchageRate() async {
    try {
      if (!_checkChatToken()) return null;

      final data = await HttpUtil.get(
        Urls.exchageRate,
        queryParameters: {
          "base": "CNY",
        },
        options: Apis.chatTokenOptions,
      );

      final exchageRateData = data;
      if (exchageRateData == null) {
        return null;
      }

      return ExchageRateInfo.fromJson(exchageRateData);
    } catch (e) {
      LogUtil.e(TAG, '查询钱包余额失败: $e');
      return null;
    }
  }

  Future<dynamic> getTokenPage({
    int page = 1,
    int pageSize = 20,
    String order = 'created_at',
  }) async {
    try {
      if (!_checkChatToken()) return false;
      final result = await HttpUtil.get(
        "${Urls.walletTokenPage}?page=$page&page_size=$pageSize&order=$order",
        options: Apis.chatTokenOptions,
      );

      if (result == "success") {

      } else {
        return null;
      }
    } catch (e) {
       LogUtil.e(TAG, '获取代币信息失败: $e');
      return null;
    }
  }

  /// 充值钱包余额
  Future<bool> walletBalanceRechargeTest(amount) async {
    try {
      if (!_checkChatToken()) return false;

      final result = await HttpUtil.post(
        Urls.walletBalanceRechargeTest,
        data: {'amount': amount},
        options: Apis.chatTokenOptions,
      );

      if (result == "success") {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      LogUtil.e(TAG, '充值钱包余额失败: $e');
      return false;
    }
  }

  /// 设置用户密钥
  ///
  /// 发送RSA公钥到服务器，获取AES密钥
  /// [publicKey] RSA公钥
  /// 返回服务器加密后的AES密钥，失败返回null
  Future<String?> setupUserKeys(String publicKey) async {
    try {
      if (!_checkChatToken()) return null;

      final result = await HttpUtil.post(
        Urls.rsaPublicKeySetUp,
        data: {'rsa_public_key': publicKey},
        options: Apis.chatTokenOptions,
      );

      // 从返回的Map中提取加密密钥，确保是base64格式
      String encryptedKey = result['encrypted_aes_key'] ?? '';
      if (encryptedKey.isEmpty) {
        return null;
      }

      // 确保密钥是base64格式
      if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(encryptedKey)) {
        LogUtil.e(TAG, '获取加密的AES密钥失败：格式不正确');
        return null;
      }

      return encryptedKey;
    } catch (e) {
      LogUtil.e(TAG, '设置用户密钥失败: $e');
      return null;
    }
  }

  /// 处理支付请求
  ///
  /// 发送加密的支付数据和签名到服务器
  /// [requestData] 包含加密数据、签名和时间戳的请求数据
  /// 返回支付处理结果
  Future<bool> processPayment(Map<String, String> requestData) async {
    try {
      if (!_checkChatToken()) return false;

      // 模拟API调用，实际开发中替换为真实接口
      await Future.delayed(Duration(milliseconds: 300));

      return true;
    } catch (e) {
      LogUtil.e(TAG, '支付处理失败: $e');
      return false;
    }
  }

  /// 更新钱包支付密码
  ///
  /// [encryptedPassword] - AES加密后的密码数据
  /// 返回更新是否成功
  Future<bool> walletPayPwdUpdate(String encryptedPassword) async {
    try {
      final result = await HttpUtil.post(
        Urls.walletPayPwdUpdate,
        data: {'encrypted_data': encryptedPassword, "need_rsa_verify": false},
        options: Apis.chatTokenOptions,
      );

      if (result == "success") {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      LogUtil.e(TAG, '更新钱包支付密码失败: $e');
      return false;
    }
  }

  /// 创建交易
  ///
  /// [encryptedData] - 加密后的交易数据
  /// [needRsaVerify] - 是否需要RSA验证
  /// 返回交易创建结果，包含success和transaction_id
  Future<Map<String, dynamic>> transactionCreate({
    required String encryptedData,
    required bool needRsaVerify,
  }) async {
    try {
      if (!_checkChatToken())
        return {'success': false, 'message': 'chat token无效'};

      final data = await HttpUtil.post(
        Urls.transactionCreate,
        data: {
          'encrypted_data': encryptedData,
          'need_rsa_verify': needRsaVerify,
        },
        options: Apis.chatTokenOptions,
      );

      if (data != null && data['transaction_id'] != null) {
        return {
          'success': true,
          'transaction_id': data['transaction_id'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '未知错误',
        };
      }
    } catch (e) {
      LogUtil.e(TAG, '创建交易失败: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// 领取交易
  Future<Map<String, dynamic>> transactionReceive({
    required String transaction_id,
    String? password
  }) async {
    try {
      if (!_checkChatToken()) {
        return {'success': false, 'code': 401, 'message': '未授权，请先登录'};
      }

      final data = await HttpUtil.post(
        Urls.transactionReceive,
        data: {
          'transaction_id': transaction_id,
          'password': password
        },
        showErrorToast:false,
        options: Apis.chatTokenOptions,
      );


      if (data != null && data['amount'] != null) {
        return {'success': true, 'code': 200, 'message': '领取成功', 'data': data};
      } else {
        return {'success': false, 'code': 400, 'message': '领取失败'};
      }
    } catch (e) {
      final error = e as (int, String);
      return {'success': false, 'code': error.$1, 'message': error.$2};
    }
  }

  /// 获取钱包交易记录
  Future<Map<String, dynamic>?> walletTsRecord({
    int? type,
    int page = 1,
    int pageSize = 20,
    String order = 'created_at',
    int? start_time,
    int? end_time,
    String? currenty_id,
    String? type_in, // 新增type_in参数，用于查询多种交易类型
  }) async {
    try {
      // 构建查询参数
      String queryParams = 'page=$page&page_size=$pageSize&order=$order';

      // 添加type参数（单类型查询）
      if (type != null) {
        queryParams += '&type=$type';
      }

      // 添加type_in参数（多类型查询）
      if (type_in != null && type_in.isNotEmpty) {
        queryParams += '&type_in=$type_in';
      }

      // 添加时间范围参数
      if (start_time != null) {
        queryParams += '&startTime=$start_time';
      }

      if (end_time != null) {
        queryParams += '&endTime=$end_time';
      }

      // 添加币种ID参数（补偿金记录查询时不传递此参数）
      if (currenty_id != null && currenty_id.isNotEmpty) {
        queryParams += '&currency_id=$currenty_id';
      }

      final data = await HttpUtil.get(
        '${Urls.walletTsRecord}?$queryParams',
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '获取钱包交易记录异常: $e');
      return null;
    }
  }

  /// 获取补偿金交易记录
  ///
  /// 根据交易类型过滤补偿金相关交易记录：
  /// - 类型51: 初始补偿金
  /// - 类型52: 补偿金扣减
  /// - 类型53: 补偿金调整
  ///
  /// 返回包含记录列表和总数的Map
  Future<Map<String, dynamic>?> getCompensationRecords({
    int page = 1,
    int pageSize = 20,
    String? currencyId,
  }) async {
    try {
      if (!_checkChatToken()) return null;

      // 创建类型过滤参数，包含所有补偿金相关交易类型
      final typeFilter = [51, 52, 53]; // 补偿金相关的交易类型

      // 构建查询参数
      final queryParams = {
        'type_in': typeFilter.join(','),  // 使用逗号分隔的多个类型
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order': 'created_at',  // 按创建时间排序
      };

      // 注意：补偿金与币种无关，不传递币种ID
      // 添加货币ID过滤条件（仅在明确指定时提供）
      if (currencyId != null && currencyId.isNotEmpty) {
        queryParams['currency_id'] = currencyId;
      }

      // 构建查询字符串
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      LogUtil.i(TAG, '获取补偿金记录请求: ${Urls.walletTsRecord}?$queryString');

      try {
        final data = await HttpUtil.get(
          '${Urls.walletTsRecord}?$queryString',
          options: Apis.chatTokenOptions,
          showErrorToast: false, // 关闭自动错误提示，由上层处理
        );

        LogUtil.i(TAG, '补偿金API原始返回: $data');

        if (data != null) {
          // 策略1: 尝试标准API响应结构 {errCode, errMsg, data: {total, data: [...]}}
          if (data is Map && data['data'] is Map) {
            final dataMap = data['data'] as Map;

            // 提取总数
            final int total = dataMap['total'] is int ? dataMap['total'] :
                             (dataMap['total'] is String ? int.tryParse(dataMap['total']) ?? 0 : 0);

            // 提取记录列表
            if (dataMap['data'] is List) {
              final List records = dataMap['data'] as List;
              LogUtil.i(TAG, '获取补偿金记录成功 (标准结构): $total 条记录, 当前页 ${records.length} 条');

              // 转换为前端期望的格式
              return {
                'total': total,
                'records': records,
              };
            }
          }

          // 策略2: 尝试旧版API响应结构 {total, records: [...]}
          if (data['records'] is List) {
            final int total = data['total'] is int ? data['total'] :
                             (data['total'] is String ? int.tryParse(data['total']) ?? 0 : 0);
            final List records = data['records'] as List;

            LogUtil.i(TAG, '获取补偿金记录成功 (旧版结构): $total 条记录, 当前页 ${records.length} 条');

            return {
              'total': total,
              'records': records,
            };
          }

          // 策略3: 尝试直接解析data字段 {data: [...]}
          if (data['data'] is List) {
            final List records = data['data'] as List;
            LogUtil.i(TAG, '获取补偿金记录成功 (简单结构): ${records.length} 条记录');

            return {
              'total': records.length,
              'records': records,
            };
          }

          // 策略4: 尝试直接使用整个返回作为记录列表
          if (data is List) {
            LogUtil.i(TAG, '获取补偿金记录成功 (列表结构): ${data.length} 条记录');
            return {
              'total': data.length,
              'records': data,
            };
          }

          // 如果以上都失败，记录错误
          LogUtil.e(TAG, '获取补偿金记录失败: 数据结构异常，不是预期的格式。API返回: $data');

          // 返回有效的空结构
          return {
            'total': 0,
            'records': [],
          };
        } else {
          LogUtil.e(TAG, '获取补偿金记录失败: 返回数据为空');
          // 返回有效的空结构
          return {
            'total': 0,
            'records': [],
          };
        }
      } catch (requestError) {
        // 处理服务器 500 错误或其他错误
        LogUtil.e(TAG, '获取补偿金记录请求失败: $requestError');

        // 返回有效的空结构，避免UI层出错
        return {
          'total': 0,
          'records': [],
        };
      }
    } catch (e) {
      LogUtil.e(TAG, '获取补偿金记录异常: $e');
      // 返回有效的空结构，避免UI层出错
      return {
        'total': 0,
        'records': [],
      };
    }
  }

  /// 查询用户🤔4小时接受交易历史记录
  Future<Map<String, dynamic>?> transactionReceiveHistory() async {
    try {
      final data = await HttpUtil.get(
        Urls.transactionReceiveHistory,
        options: Apis.chatTokenOptions,
      );

      if (data == null) {
        return null;
      }

      if (data['total'] == null) {
        return null;
      }

      // 确保返回的是Map类型
      if (data['records'] is List) {
        return {
          'total': data['total'],
          'records': data['records'],
          'timestamp': DateTime.now().millisecondsSinceEpoch
        };
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '查询用户24小时接受交易历史记录异常: $e');
      return null;
    }
  }

  /// 检查转账是否已领取
  Future<Map<String, dynamic>?> transactionCheckReceived({
    required String transaction_id,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.transactionCheckReceived,
        data: {
          'transaction_id': transaction_id,
        },
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '检查转账状态异常: $e');
      return null;
    }
  }

  /// 检查交易是否已领完、当前用户是否已领取（服务端权威状态，用于进入会话后恢复红包状态）
  /// 必须请求 check_completed 接口，返回 completed + received；勿用 check_received
  Future<Map<String, dynamic>?> transactionCheckCompleted({
    required String transaction_id,
  }) async {
    try {
      final headers = Map<String, dynamic>.from(Apis.chatTokenOptions.headers ?? {});
      final imUserID = DataSp.userID;
      if (imUserID != null && imUserID.isNotEmpty) {
        // dawn 2026-05-14 修复红包重登后误显示待领取：带上 IM 用户ID，服务端可按 user_id/user_im_id 双路查询领取记录。
        headers['X-User-IM-ID'] = imUserID;
      }
      final data = await HttpUtil.post(
        Urls.transactionCheckCompleted,
        data: {
          'transaction_id': transaction_id,
        },
        options: Options(headers: headers),
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '检查交易状态异常: $e');
      return null;
    }
  }

  /// 查询交易领取详情（支持分页）
  /// [opUserImId] 可选，当前用户 IM ID；传入后作为请求头 X-User-IM-ID，服务端在 token 无操作人时用其查领取记录，避免重装/多端后显示 0.00
  /// [pageNum] / [pageSize] 可选：不传则返回全部记录，传入则按页返回
  Future<Map<String, dynamic>?> transactionReceiveDetails({
    required String transaction_id,
    String? opUserImId,
    int? pageNum,
    int? pageSize,
  }) async {
    try {
      final headers = Map<String, dynamic>.from(Apis.chatTokenOptions.headers ?? {});
      if (opUserImId != null && opUserImId.isNotEmpty) {
        headers['X-User-IM-ID'] = opUserImId;
      }
      final params = <String, String>{'transaction_id': transaction_id};
      if (pageNum != null) {
        params['page_num'] = pageNum.toString();
      }
      if (pageSize != null) {
        params['page_size'] = pageSize.toString();
      }
      final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');

      final data = await HttpUtil.get(
        '${Urls.transactionReceiveDetails}?$query',
        options: Options(headers: headers),
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '查询交易领取详情失败: $e');
      return null;
    }
  }

  /// 同意观众的举手申请
  Future<Map<String, dynamic>?> approveHandRaise({
    required String identity,
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.approveHandRaise,
        data: {'identity': identity, "room_name": roomName},
        options: Apis.chatTokenOptions,
      );

      ILogger.d('同意观众的举手申请$data');

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '同意观众的举手申请失败: $e');
      return null;
    }
  }

  /// 拒绝观众的举手申请 或者请下台
  Future<Map<String, dynamic>?> removeFromStage({
    required String identity,
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.removeFromStage,
        data: {'identity': identity, "room_name": roomName},
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '拒绝观众的举手申请失败: $e');
      return null;
    }
  }

  /// 邀请观众上台
  Future<Map<String, dynamic>?> inviteToStage({
    required String identity,
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.inviteToStage,
        data: {'identity': identity, "room_name": roomName},
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '邀请观众上台: $e');
      return null;
    }
  }

  /// 取消管理员
  Future<Map<String, dynamic>?> revokeAdmin({
    required String identity,
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.revokeAdmin,
        data: {'identity': identity, "room_name": roomName},
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '取消管理员失败: $e');
      return null;
    }
  }

  /// 设置管理员
  Future<Map<String, dynamic>?> setAdmin({
    required String identity,
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.setAdmin,
        data: {'identity': identity, "room_name": roomName},
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '设置管理员失败: $e');
      return null;
    }
  }

  /// 创建新的直播间
  Future<Map<String, dynamic>?> createStream({
    required Object metadata,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.createStream,
        data: {
          'metadata': metadata,
        },
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '创建新的直播间: $e');
      return null;
    }
  }

  /// 加入已有的直播房间
  Future<Map<String, dynamic>?> joinStream({
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.joinStream,
        data: {
          'room_name': roomName,
        },
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '加入已有的直播房间: $e');
      return null;
    }
  }

  /// 获取直播会议列表
  Future<Map<String, dynamic>?> livestreamStatisticsList({
    int page = 1,
    int page_size = 20,
    required String keyword,

  }) async {
    try {
      final data = await HttpUtil.get(
        '${Urls.livestreamStatisticsList}?page=${page}&page_size=${page_size}&keyword=${keyword}',
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '查询交易领取详情失败: $e');
      return null;
    }
  }

  /// 举手上台
  Future<Map<String, dynamic>?> raiseHand({
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.raiseHand,
        data: {
          'room_name': roomName,
        },
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '举手上台: $e');
      return null;
    }
  }

  /// 将用户加入直播房间黑名单
  Future<Map<String, dynamic>?> blockViewer({
    required String roomName,
    required String identity,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.blockViewer,
        data: {'room_name': roomName, 'identity': identity},
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '将用户加入直播房间黑名单: $e');
      return null;
    }
  }

  /// 停止当前的直播
  Future<Map<String, dynamic>?> stopStream({
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.post(
        Urls.stopStream,
        data: {
          'room_name': roomName,
        },
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '停止当前的直播: $e');
      return null;
    }
  }

  /// 获取单个房间统计记录
  Future<Map<String, dynamic>?> livestreamStatisticsSingle({
    required String roomName,
  }) async {
    try {
      final data = await HttpUtil.get(
        '${Urls.livestreamStatisticsSingle}?room_name=${roomName}',
        options: Apis.chatTokenOptions,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '获取单个房间统计记录: $e');
      return null;
    }
  }

  /// 获取上传分片大小
  Future<Map<String, dynamic>?> getUploadPartSize({
    required int size,
  }) async {
    try {
      final options = Apis.imTokenOptions.copyWith(
        headers: {
          ...Apis.imTokenOptions.headers ?? {},
          'operationID': const Uuid().v4(),
        },
      );

      final data = await HttpUtil.post(
        Urls.getUploadPartSize,
        data: {
          'size': size,
        },
        options: options,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '获取上传分片大小失败: $e');
      return null;
    }
  }

  /// 获取上传URL
  Future<Map<String, dynamic>?> getUploadUrl({
    required String hash,
    required int size,
    required int partSize,
    required int maxParts,
    required String cause,
    required String name,
    required String contentType,
  }) async {
    try {
      final options = Apis.imTokenOptions.copyWith(
        headers: {
          ...Apis.imTokenOptions.headers ?? {},
          'operationID': const Uuid().v4(),
        },
      );

      final data = await HttpUtil.post(
        Urls.getUploadUrl,
        data: {
          'hash': hash,
          'size': size,
          'partSize': partSize,
          'maxParts': maxParts,
          'cause': cause,
          'name': name,
          'contentType': contentType,
        },
        options: options,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '获取上传URL失败: $e');
      return null;
    }
  }

  /// 确认上传
  Future<Map<String, dynamic>?> confirmUpload({
    required String uploadID,
    required List<String> parts,
    required String cause,
    required String name,
    required String contentType,
  }) async {
    try {
      final options = Apis.imTokenOptions.copyWith(
        headers: {
          ...Apis.imTokenOptions.headers ?? {},
          'operationID': const Uuid().v4(),
        },
      );

      final data = await HttpUtil.post(
        Urls.confirmUpload,
        data: {
          'uploadID': uploadID,
          'parts': parts,
          'cause': cause,
          'name': name,
          'contentType': contentType,
        },
        options: options,
      );

      if (data != null) {
        return data;
      } else {
        return null;
      }
    } catch (e) {
      LogUtil.e(TAG, '确认上传失败: $e');
      return null;
    }
  }

  /// 检查用户是否拥有官方账号保护权限
  ///
  /// [userID] - 要检查的用户ID
  /// 返回用户是否受保护，受保护的用户不能被发起音视频通话、踢出群组、禁言
  Future<bool> checkUserHasProtection(String userID) async {
    try {
      final data = await HttpUtil.get(
        '${Urls.checkUserProtection}?user_id=$userID',
        showErrorToast: false,
        options: Apis.chatTokenOptions,
      );
      return data?['has_protection'] ?? false;
    } catch (e) {
      return false;
    }
  }
}
