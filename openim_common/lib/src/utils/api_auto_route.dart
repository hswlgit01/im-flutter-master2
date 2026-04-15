import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:openim_common/src/utils/data_sp.dart';

/// API自动寻路工具类
/// 负责从CDN获取服务器列表，测试服务器响应时间，选择最快的服务器
class ApiAutoRoute {
  static Map<String, dynamic>? _cdnConfig;
  static String? _currentHost;
  static Function(String)? _onRouteChanged;
  static Function()? _onRouteFailure;

  /// 当前环境
  static String _environment = 'test';

  /// 设置环境
  static void setEnvironment(String environment) {
    _environment = environment;
    print('设置寻路环境: $environment');
  }

  /// 寻找最快的服务器
  static Future<String?> findFastestServer() async {
    print('开始自动寻路 (环境: $_environment)');

    try {
      // 获取服务器列表
      final servers = await _getServerList(_environment);

      if (servers.isEmpty) {
        print('未获取到服务器配置');
        return null;
      }

      print('获取到 ${servers.length} 个服务器');

      // 测试所有服务器
      final results = await _testServers(servers);

      // 选择最快的服务器
      final fastest = _selectFastest(results);

      if (fastest != null) {
        _currentHost = fastest.host;
        print(
            '选择服务器: ${fastest.name} (${results.where((r) => r.server == fastest).first.responseTime}ms)');
        return fastest.host;
      } else {
        print('所有服务器测试失败');
        return null;
      }
    } catch (e) {
      print('自动寻路异常: $e');
      return null;
    }
  }

  /// 手动触发一次寻路
  static Future<String?> manualRoute() async {
    print('手动寻路...');
    return await findFastestServer();
  }

  /// 接口请求失败时触发重新寻路
  static Future<void> onRequestFailed() async {
    try {
      print('接口请求失败，触发重新寻路');
      
      if (_onRouteFailure != null) {
        _onRouteFailure!();
      }

      final newHost = await findFastestServer();
      if (newHost != null && newHost != _currentHost) {
        print('切换到新服务器: $newHost');
        if (_onRouteChanged != null) {
          _onRouteChanged!(newHost);
        }
      }
    } catch (e) {
      print('重新寻路失败: $e');
    }
  }

  /// 设置回调函数
  static void setCallbacks({
    Function(String)? onRouteChanged,
    Function()? onFailure,
  }) {
    _onRouteChanged = onRouteChanged;
    _onRouteFailure = onFailure;
  }

  /// 获取状态
  static String? get currentHost => _currentHost;

  /// 默认服务器配置 (空列表 - 依赖远程配置)
  static final List<ApiServerConfig> _defaultServers = [];

  /// 当前备用地址列表
  static final List<String> _backupUrls = ['', '']; // 初始化为两个空字符串，便于更新操作

  /// 获取备用配置地址
  static List<String> getBackupUrls(String environment) {
    return _backupUrls;
  }

  /// 更新备用地址列表
  static void _updateBackupUrls(String newBackupUrl) {
    // 将第二个地址变成第一个
    _backupUrls[0] = _backupUrls[1];
    // 新地址变成第二个
    _backupUrls[1] = newBackupUrl;
    print('更新备用地址列表: $_backupUrls');
  }

  /// 从远程配置获取服务器列表
  static List<ApiServerConfig> _getConfiguredServers() {
    final remoteConfig = DataSp.getRemoteConfig();

    // 尝试从远程配置获取
    if (remoteConfig != null && remoteConfig.containsKey('servers')) {
      try {
        final List<dynamic> serversList = remoteConfig['servers'];
        if (serversList.isNotEmpty) {
          print('使用远程配置的${serversList.length}个服务器');
          return serversList
              .map((server) => ApiServerConfig.fromJson(server))
              .toList();
        }
      } catch (e) {
        print('解析远程服务器列表失败: $e');
      }
    }

    // 回退到默认服务器列表
    print('使用默认的${_defaultServers.length}个服务器');
    return _defaultServers;
  }

  /// 获取服务器列表
  static Future<List<ApiServerConfig>> _getServerList(String environment) async {
    // 1. 先尝试从远程配置获取的服务器
    print('尝试远程配置的服务器...');
    List<ApiServerConfig> configuredServers = _getConfiguredServers();

    // 测试远程配置服务器
    final configResults = await _testServers(configuredServers);
    final workingConfigServers = configResults
        .where((result) => result.isSuccess)
        .map((result) => result.server)
        .toList();

    if (workingConfigServers.isNotEmpty) {
      print('远程配置的服务器可用，使用远程配置服务器');
      return workingConfigServers;
    }

    // 2. 尝试默认服务器（如果与远程服务器不同）
    print('远程服务器不可用，尝试默认服务器...');
    final defaultResults = await _testServers(_defaultServers);
    final workingDefaultServers = defaultResults
        .where((result) => result.isSuccess)
        .map((result) => result.server)
        .toList();

    if (workingDefaultServers.isNotEmpty) {
      print('默认服务器可用，使用默认服务器');
      return workingDefaultServers;
    }

    print('默认服务器均不可用，尝试获取新的服务器配置...');

    // 3. 尝试备用配置
    final backupUrls = getBackupUrls(environment);
    final backupServers = await _tryGetServersFromCDN(backupUrls, '备用');
    if (backupServers.isNotEmpty) {
      // 更新默认服务器配置
      _updateDefaultServers(backupServers);
      return backupServers;
    }

    // 4. 所有尝试都失败，返回空列表
    print('警告: 所有服务器获取失败');
    return [];
  }

  /// 更新默认服务器配置
  static void _updateDefaultServers(List<ApiServerConfig> newServers) {
    if (newServers.length >= 2) {
      print('更新默认服务器配置');
      _defaultServers.clear();
      _defaultServers.addAll([
        newServers[0].copyWith(priority: 1),
        newServers[1].copyWith(priority: 2),
      ]);
    }
  }

  /// 从CDN获取服务器列表
  static Future<List<ApiServerConfig>> _tryGetServersFromCDN(
      List<String> cdnUrls, String cdnType) async {
    bool firstUrlFailed = false;  // 标记第一个地址是否失败

    for (int i = 0; i < cdnUrls.length; i++) {
      String cdnUrl = cdnUrls[i];
      try {
        print('尝试${cdnType}CDN: $cdnUrl');

        final uri = Uri.parse(cdnUrl);
        print('主机名: ${uri.host}');
        print('协议: ${uri.scheme}');
        print('端口: ${uri.port}');

        final dio = Dio();
        dio.options.connectTimeout = Duration(seconds: 15);
        dio.options.receiveTimeout = Duration(seconds: 15);

        dio.interceptors.add(LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (obj) => print('🌐 网络请求: $obj'),
        ));

        final stopwatch = Stopwatch()..start();
        final response = await dio.get(cdnUrl);
        stopwatch.stop();

        if (response.statusCode == 200 && response.data != null) {
          print('${cdnType}CDN成功 (${stopwatch.elapsedMilliseconds}ms)');

          _cdnConfig = response.data;
          
          // 只有当第一个地址失败，且是第二个地址成功时才更新地址列表
          if (firstUrlFailed && i == 1 && _cdnConfig!['backup_url'] != null) {
            _updateBackupUrls(_cdnConfig!['backup_url']);
          }

          final List<dynamic> nodesList = response.data['nodes'] ?? [];
          final servers = nodesList.map((json) => ApiServerConfig.fromJson(json)).toList();

          if (servers.isNotEmpty) {
            servers.sort((a, b) => a.priority.compareTo(b.priority));
            print('从${cdnType}CDN解析到 ${servers.length} 个服务器');
            return servers;
          }
        }
      } catch (e) {
        print('${cdnType}CDN获取失败: $e');
        if (i == 0) {
          // 标记第一个地址失败
          firstUrlFailed = true;
          print('第一个地址失败，尝试第二个地址');
          continue;
        }
      }
    }

    return [];
  }

  /// 测试服务器速度
  static Future<List<_ServerTestResult>> _testServers(
      List<ApiServerConfig> servers) async {
    final results = await Future.wait(
      servers.map((server) => _testSingleServer(server)),
      eagerError: false,
    );

    return results;
  }

  /// 测试单个服务器
  static Future<_ServerTestResult> _testSingleServer(
      ApiServerConfig server) async {
    final stopwatch = Stopwatch()..start();

    try {
      final dio = Dio();

      // 配置SSL证书验证
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) {
          // 允许所有证书，解决hostname不匹配问题
          print('SSL证书验证: ${server.host} -> $host (忽略证书错误)');
          return true;
        };
        return client;
      };

      // 使用CDN配置的超时设置
      int timeoutSeconds = 8;
      if (_cdnConfig != null && _cdnConfig!['config'] != null) {
        final timeout = _cdnConfig!['config']['timeout'];
        if (timeout != null) {
          timeoutSeconds = (timeout / 1000).round();
        }
      }

      dio.options.connectTimeout = Duration(seconds: timeoutSeconds);
      dio.options.receiveTimeout = Duration(seconds: timeoutSeconds);

      // 构建测试URL
      final isIP = RegExp(
              r'^((2[0-4]\d|25[0-5]|[01]?\d\d?)\.){3}(2[0-4]\d|25[0-5]|[01]?\d\d?)$')
          .hasMatch(server.host);
      final protocol = isIP ? 'http' : 'https';
      final port = isIP ? ':10002' : '';
      // 根据Nginx配置，使用chat.domain.com格式
      final chatDomain = isIP ? server.host : 'chat.${server.host}';
      final testUrl =
          '$protocol://${chatDomain}$port/third/network/test/ping';

      print('测试服务器: ${server.name} -> $testUrl');

      // 准备请求头
      final headers = <String, dynamic>{
        'operationID': '${DateTime.now().millisecondsSinceEpoch}',
        'orgId': 'orgId',
      };

      if (Platform.isIOS) {
        headers['source'] = 'ios';
      } else if (Platform.isAndroid) {
        headers['source'] = 'android';
      }

      final response = await dio.get(
        testUrl,
        options: Options(headers: headers),
      );
      stopwatch.stop();

      final responseTime = stopwatch.elapsedMilliseconds;
      final isSuccess = response.statusCode == 200;

      print(
          '${server.name}: ${isSuccess ? '成功' : '失败'} (${responseTime}ms, 状态:${response.statusCode})');

      return _ServerTestResult(
        server: server,
        responseTime: responseTime,
        isSuccess: isSuccess,
      );
    } catch (e) {
      stopwatch.stop();
      print('${server.name}: 连接失败 - $e');

      return _ServerTestResult(
        server: server,
        responseTime: 99999,
        isSuccess: false,
      );
    }
  }

  /// 选择最快的服务器
  static ApiServerConfig? _selectFastest(List<_ServerTestResult> results) {
    final successResults = results.where((r) => r.isSuccess).toList();

    if (successResults.isEmpty) {
      return null;
    }

    successResults.sort((a, b) => a.responseTime.compareTo(b.responseTime));

    final fastest = successResults.first;
    return fastest.server;
  }
}

/// API服务器配置
class ApiServerConfig {
  final String name;
  final String host;
  final int priority;
  final String region;

  const ApiServerConfig({
    required this.name,
    required this.host,
    required this.priority,
    required this.region,
  });

  factory ApiServerConfig.fromJson(Map<String, dynamic> json) {
    return ApiServerConfig(
      name: json['name'] ?? 'unknown',
      host: json['domain'] ?? json['host'] ?? '',
      priority: json['priority'] ?? 0,
      region: json['region'] ?? 'global',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'host': host,
      'priority': priority,
      'region': region,
    };
  }

  @override
  String toString() {
    return 'ApiServerConfig{name: $name, host: $host, priority: $priority, region: $region}';
  }

  ApiServerConfig copyWith({
    String? name,
    String? host,
    int? priority,
    String? region,
  }) {
    return ApiServerConfig(
      name: name ?? this.name,
      host: host ?? this.host,
      priority: priority ?? this.priority,
      region: region ?? this.region,
    );
  }
}

/// 服务器测试结果
class _ServerTestResult {
  final ApiServerConfig server;
  final int responseTime;
  final bool isSuccess;

  const _ServerTestResult({
    required this.server,
    required this.responseTime,
    required this.isSuccess,
  });
}
