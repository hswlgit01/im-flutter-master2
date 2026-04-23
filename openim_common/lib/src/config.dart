import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:openim_common/openim_common.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class Config {
  // 远程配置URL - 更改此URL以获取远程服务器配置
  static const String remoteConfigUrl = "http://serverapi.zwzwfn.cn/servers.json";
  // static const String remoteConfigUrl = "";

  // 定义不同环境的主机
  /// 本地开发默认用 10.0.2.2（Android 模拟器访问宿主机）；真机请用 flutter run --dart-define=DEV_HOST=你的电脑局域网IP
  static const String _devHost = "";
  static const String _testHost = "57.180.51.222";   // 测试环境服务器
  // 生产环境服务器：默认 fallback。Config.init() 仍会先尝试从 remoteConfigUrl
  // 拉 servers.json 走 API 自动寻路，那份配置拉不到 / 里面没有可用节点时，
  // 就退回这个默认值，避免 serverIp 为空导致 init 抛异常（白屏）。
  static const String _prodHost = "8.148.66.77";   // 生产环境服务器

  // 从环境变量获取当前环境，默认为dev（本地开发）
  static final String _currentEnv = const String.fromEnvironment('ENV', defaultValue: 'dev');
  /// 开发环境主机覆盖：可手动指定，如 flutter run --dart-define=DEV_HOST=10.0.2.2
  static const String _devHostOverride = String.fromEnvironment('DEV_HOST', defaultValue: '');
  /// Android 模拟器访问宿主机专用地址（ENV=dev 且未设置 DEV_HOST 时会自动检测模拟器并使用）
  static const String _devHostEmulator = '10.0.2.2';

  // 根据当前环境获取主机（同步，用于 getter；开发环境实际使用 _getDevHostAsync 的结果）
  static String get _host {
    switch (_currentEnv) {
      case "dev":
        return _devHostOverride.isNotEmpty ? _devHostOverride : _devHost;
      case "prod": return _prodHost;
      case "test":
      default: return _testHost;
    }
  }

  /// 开发环境下解析实际使用的主机：优先 DEV_HOST，否则 Android 模拟器用 10.0.2.2，真机用 _devHost
  static Future<String> _getDevHostAsync() async {
    if (_devHostOverride.isNotEmpty) return _devHostOverride;
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (!androidInfo.isPhysicalDevice) {
          print('🔧 【开发环境】检测到 Android 模拟器，使用宿主机地址 $_devHostEmulator');
          return _devHostEmulator;
        }
      } catch (e) {
        print('⚠️ 获取设备信息失败，使用默认 dev 主机: $e');
      }
    }
    return _devHost;
  }
  
  static Future init(Function() runApp) async {
    print('📱📱📱 main() 函数开始执行！！！');

    // 🚨🚨🚨 强制清除存储配置，确保自动寻路执行
    WidgetsFlutterBinding.ensureInitialized();
    await DataSp.init();

    print('🗑️🗑️🗑️ 正在清除旧的服务器配置...');
    final sp = SpUtil();
    await sp.init();
    await sp.remove('server'); // 清除服务器配置

    print('🧹🧹🧹 正在清除所有缓存...');
    await sp.remove('auto_route_host');
    await sp.remove('auto_route_time');
    print('✅✅✅ 所有配置已清除，即将执行自动寻路');

    print('🚀🚀🚀 Config.init() 方法被调用！！！');

    try {
      final path = (await getApplicationDocumentsDirectory()).path;
      cachePath = '$path/';
      await Hive.initFlutter(path);
      MediaKit.ensureInitialized();

      // 尝试获取远程服务器配置
      print('🌐 尝试获取远程服务器配置...');
      await _fetchRemoteConfig();

      print('🌐 开始API自动寻路...');
      await _performApiAutoRoute();

      // 开发环境：若 server 仍为空则用 _devHost 强制写一次，确保登录等请求有正确 base
      if (_currentEnv == 'dev' && (serverIp.isEmpty || DataSp.getServerConfig() == null)) {
        print('⚠️ 【开发环境】补写服务器配置，使用 _devHost: $_devHost');
        await _updateServerConfig(_devHost);
      }

      if (serverIp.isEmpty) {
        throw Exception('自动寻路失败：无法获取有效的服务器配置');
      }

      print('🌐 初始化网络工具...');
      HttpUtil.init();
      ApiService().setBaseUrl(imApiUrl);

      print('✅ 自动寻路完成');

      // 输出当前环境信息（调试用）
      print('当前环境: $_currentEnv');
    } catch (e) {
      print('❌ Config.init() 异常: $e');
      throw e; // 向上抛出异常，让应用知道初始化失败
    }

    runApp();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    var brightness = Platform.isAndroid ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: brightness,
      statusBarIconBrightness: brightness,
    ));

    final packageInfo = await PackageInfo.fromPlatform();
    _appName = packageInfo.appName;
  }

  static late String _appName;

  static late String cachePath;
  static const uiW = 375.0;
  static const uiH = 812.0;

  static const double textScaleFactor = 1.0;

  static const discoverPageURL = 'https://docs.openim.io/';
  static const allowSendMsgNotFriend = '1';
  
  // amap key
  static const webKey = 'webKey';
  static const webServerKey = 'webServerKey';
  static const locationHost = 'http://location.your-domain';

  static OfflinePushInfo get offlinePushInfo => OfflinePushInfo(
        title: _appName,
        desc: StrRes.offlineMessage,
        iOSBadgeCount: true,
      );

  static const friendScheme = "io.openim.app/addFriend/";
  static const groupScheme = "io.openim.app/joinGroup/";
  
  static const _ipRegex = '((2[0-4]\\d|25[0-5]|[01]?\\d\\d?)\\.){3}(2[0-4]\\d|25[0-5]|[01]?\\d\\d?)';

  static bool get _isIP => RegExp(_ipRegex).hasMatch(_host);

  static String get serverIp {
    String? ip;
    var server = DataSp.getServerConfig();
    if (null != server) {
      ip = server['serverIP'];
    }
    return ip ?? _host;
  }

  static String get chatTokenUrl {
    String? url;
    var server = DataSp.getServerConfig();
    if (null != server) {
      url = server['chatTokenUrl'];
    }
    return url ?? (_isIP ? "http://$_host:10009" : "https://$_host/chat");
  }

  static String get appAuthUrl {
    String? url;
    var server = DataSp.getServerConfig();
    if (null != server) {
      url = server['authUrl'];
    }
    return url ?? (_isIP ? "http://$_host:10008" : "https://$_host/chat");
  }

  static String get imApiUrl {
    String? url;
    var server = DataSp.getServerConfig();
    if (null != server) {
      url = server['apiUrl'];
    }
    return url ?? (_isIP ? 'http://$_host:10002' : "https://$_host/api");
  }

  static String get imWsUrl {
    String? url;
    var server = DataSp.getServerConfig();
    if (null != server) {
      url = server['wsUrl'];
    }
    return url ?? (_isIP ? "ws://$_host:10001" : "wss://ws.$_host");
  }

  static int get logLevel {
    String? level;
    var server = DataSp.getServerConfig();
    if (null != server) {
      level = server['logLevel'];
    }
    return level == null ? 5 : int.parse(level);
  }
  
  // 方便外部检查当前环境
  static bool get isDevEnv => _currentEnv == 'dev';
  static bool get isTestEnv => _currentEnv == 'test';
  static bool get isProdEnv => _currentEnv == 'prod';
  static String get currentEnv => _currentEnv;

  /// 执行API自动寻路
  static Future<void> _performApiAutoRoute() async {
    try {
      print('Config 初始化开始 (环境: $_currentEnv)');
      
      // 开发环境：自动选主机（模拟器 10.0.2.2，真机 _devHost，或 DEV_HOST 覆盖）
      if (_currentEnv == 'dev') {
        final host = await _getDevHostAsync();
        if (_devHostOverride.isNotEmpty) {
          print('🔧 【自动寻路】开发环境 + DEV_HOST 覆盖: $host');
        } else {
          print('🔧 【自动寻路】开发环境: $host');
        }
        await _updateServerConfig(host);
        print('✅ 【自动寻路】初始化完成，服务器: ${serverIp}');
        return;
      }
      
      // 设置自动寻路环境
      ApiAutoRoute.setEnvironment(_currentEnv);
      
      // 检查缓存
      final sp = SpUtil();
      await sp.init();
      
      final cachedHost = sp.getString('auto_route_host');
      final cacheTime = sp.getInt('auto_route_time');
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheValidityHours = 6;
      
      if (cachedHost != null && 
          cacheTime != null && 
          (now - cacheTime) < (cacheValidityHours * 60 * 60 * 1000)) {
        print('使用缓存服务器: $cachedHost');
        await _updateServerConfig(cachedHost);
      } else {
        print('缓存过期或不存在，开始寻路...');
        
        // 执行自动寻路
        final selectedHost = await ApiAutoRoute.findFastestServer();
        
        if (selectedHost != null) {
          print('自动寻路成功，选择服务器: $selectedHost');
          await _updateServerConfig(selectedHost);
          
          // 保存到缓存
          await sp.putString('auto_route_host', selectedHost);
          await sp.putInt('auto_route_time', now);
        } else {
          print('自动寻路失败，使用默认配置');
        }
      }
      
      // 设置回调函数
      ApiAutoRoute.setCallbacks(
        onRouteChanged: (newHost) async {
          print('服务器切换: $newHost');
          await _updateServerConfig(newHost);
          
          // 更新缓存
          await sp.putString('auto_route_host', newHost);
          await sp.putInt('auto_route_time', DateTime.now().millisecondsSinceEpoch);
        },
        onFailure: () {
          print('接口请求失败，准备重新寻路');
        },
      );
      
      print('Config 初始化完成，服务器: ${serverIp}');
      
    } catch (e) {
      print('自动寻路异常: $e');
    }
  }
  
  /// 手动触发自动寻路
  static Future<void> manualAutoRoute() async {
    try {
      print('手动触发自动寻路...');

      // 开发环境不执行手动寻路
      if (_currentEnv == 'dev') {
        return;
      }

      // 使用带时间戳的URL刷新远程配置
      await _fetchRemoteConfig();

      final selectedHost = await ApiAutoRoute.manualRoute();

      if (selectedHost != null) {
        await _updateServerConfig(selectedHost);

        // 更新缓存
        final sp = SpUtil();
        await sp.init();
        await sp.putString('auto_route_host', selectedHost);
        await sp.putInt('auto_route_time', DateTime.now().millisecondsSinceEpoch);

        print('手动寻路完成: $selectedHost');
      } else {
        print('手动寻路失败');
      }
    } catch (e) {
      print('手动寻路异常: $e');
    }
  }

  /// 获取远程配置
  static Future<void> _fetchRemoteConfig() async {
    try {
      // 使用5秒超时，确保不会卡住应用启动
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);

      // 设置禁用缓存的头信息
      dio.options.headers = {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      };

      // 智能拼接时间戳参数，防止缓存
      String urlWithTimestamp = _appendTimestampToUrl(remoteConfigUrl);
      print('🌐 【远程配置】尝试从 $urlWithTimestamp 获取服务器列表...');
      final response = await dio.get(urlWithTimestamp);

      if (response.statusCode == 200 && response.data != null) {
        // 检查是否包含servers字段
        final configData = response.data;
        if (configData is Map<String, dynamic> && configData.containsKey('servers')) {
          final serversList = configData['servers'] as List;
          // 保存完整配置
          await DataSp.putRemoteConfig(configData);
          print('✅ 【远程配置】获取成功! 共获取到 ${serversList.length} 个服务器配置');

          // 检查是否包含app_version字段
          if (configData.containsKey('app_version')) {
            print('✅ 【远程配置】成功获取app_version信息');
          }

          // 打印服务器列表
          int index = 1;
          for (var server in serversList) {
            if (server is Map) {
              final name = server['name'] ?? 'unknown';
              final host = server['host'] ?? 'unknown';
              final priority = server['priority'] ?? 0;
              print('   ${index++}. $name ($host) - 优先级: $priority');
            }
          }
        } else {
          print('⚠️ 【远程配置】格式不正确，未找到servers字段，将使用默认配置');
        }
      }
    } catch (e) {
      print('⚠️ 【远程配置】获取失败，将使用默认配置');
      print('   原因: $e');
      // 获取失败不抛出异常，静默失败，使用原配置
    }
  }
  
  /// 智能拼接时间戳参数到URL
  /// 无论URL是否已包含查询参数，都能正确添加时间戳
  static String _appendTimestampToUrl(String url) {
    if (url.isEmpty) return url;

    // 生成时间戳参数
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      // 使用Uri解析URL
      final uri = Uri.parse(url);

      // 复制现有查询参数并添加时间戳
      final queryParams = Map<String, dynamic>.from(uri.queryParameters);
      queryParams['_t'] = timestamp.toString();

      // 重建URL
      final newUri = uri.replace(queryParameters: queryParams);
      return newUri.toString();
    } catch (e) {
      // URL解析失败，使用简单的字符串拼接
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}_t=$timestamp';
    }
  }

  /// 更新服务器配置
  static Future<void> _updateServerConfig(String host) async {
    try {
      final isIP = RegExp(r'^((2[0-4]\d|25[0-5]|[01]?\d\d?)\.){3}(2[0-4]\d|25[0-5]|[01]?\d\d?)$').hasMatch(host);
      
      final serverConfig = {
        'serverIP': host,
        'authUrl': isIP ? "http://$host:10008" : "https://$host/chat",
        'chatTokenUrl': isIP ? "http://$host:10009" : "https://$host/chat",
        'apiUrl': isIP ? 'http://$host:10002' : "https://$host/api",
        'wsUrl': isIP ? "ws://$host:10001" : "wss://ws.$host",
        'logLevel': '2',
      };
      
      await DataSp.putServerConfig(serverConfig);

      print('📡 【服务器配置】成功更新! 主机: $host (${isIP ? "IP模式" : "域名模式"})');
      print('┌──────────────────────────────────────────────────────────────────────');
      print('│ 🔌 API地址:       ${serverConfig['apiUrl']}');
      print('│ 🔄 WebSocket地址:  ${serverConfig['wsUrl']}');
      print('│ 🔑 授权地址:       ${serverConfig['authUrl']}');
      print('│ 🎟️ Chat Token地址: ${serverConfig['chatTokenUrl']}');
      print('└──────────────────────────────────────────────────────────────────────');

    } catch (e) {
      print('更新服务器配置失败: $e');
    }
  }
}