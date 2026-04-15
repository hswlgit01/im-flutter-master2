import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:getuiflut/getuiflut.dart';

import 'firebase_options.dart';

enum PushType { FCM, GeTui, none }

// GeTui 配置
const appID = 'u7XipjV3Dt6qDLMhwRE8U2';
const appKey = 'K3QdSzBF3D7k8a1o3JSNL2';
const appSecret = '2dMXR8K7cm62MAbcf72fz5';

class PushController extends GetxService {
  PushType pushType = PushType.GeTui;  // 使用 GeTui 推送?
  /// Logs in the user with the specified alias to the push notification service.
  ///
  /// Depending on the push type configured, it either logs in using the Getui or
  /// FCM push service.
  ///
  /// If using Getui, it binds the alias to the Getui service.
  ///
  /// If using FCM, it listens for token refresh events and logs in, invoking the
  /// provided callback with the new token.
  ///
  /// Throws an assertion error if the FCM push type is selected but the
  /// `onTokenRefresh` callback is not provided.
  ///
  /// - Parameters:
  ///   - alias: The alias to bind to the push notification service for getui.
  ///   - onTokenRefresh: A callback function that is invoked with the refreshed
  ///     token when using FCM. Required if the push type is FCM.
  static void login(String alias, {void Function(String token)? onTokenRefresh}) {
    if (PushController().pushType == PushType.GeTui) {
      GetuiPushController()._initialize(alias, onTokenRefresh: onTokenRefresh);
    } else if (PushController().pushType == PushType.FCM) {
      assert((PushController().pushType == PushType.FCM && onTokenRefresh != null));

      FCMPushController()._initialize().then((_) {
        FCMPushController()._getToken().then((token) => onTokenRefresh!(token));
        FCMPushController()._listenToTokenRefresh((token) => onTokenRefresh);
      });
    }
  }

  static void logout() {
    if (PushController().pushType == PushType.GeTui) {
      GetuiPushController()._unbindAlias();
    } else if (PushController().pushType == PushType.FCM) {
      FCMPushController()._deleteToken();
    }
  }
}

class FCMPushController {
  static final FCMPushController _instance = FCMPushController._internal();
  factory FCMPushController() => _instance;

  FCMPushController._internal();

  Future<void> _initialize() async {
    // GooglePlayServicesAvailability? availability = GooglePlayServicesAvailability.success;
    // if (Platform.isAndroid) {
    //   availability = await GoogleApiAvailability.instance.checkGooglePlayServicesAvailability();
    // }
    // if (availability != GooglePlayServicesAvailability.serviceInvalid) {
    //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // } else {
    //   return;
    // }
    //
    // await _requestPermission();
    //
    // _configureForegroundNotification();
    //
    // _configureBackgroundNotification();

    return;
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
    print('User granted permission: ${settings.authorizationStatus}');
  }

  void _configureForegroundNotification() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('Foreground notification received: ${message.notification?.title}');

      if (message.notification != null) {}
    });
  }

  void _configureBackgroundNotification() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background: ${message.notification?.title}');
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from terminated state: ${message.notification?.title}');
      }
    });
  }

  Future<String> _getToken() async {
    final token = await FirebaseMessaging.instance.getToken();

    if (token == null) {
      throw Exception('FCM Token is null');
    }

    return token;
  }

  Future<void> _deleteToken() {
    return FirebaseMessaging.instance.deleteToken();
  }

  void _listenToTokenRefresh(void Function(String token) onTokenRefresh) {
    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
      print("FCM Token refreshed: $newToken");
      onTokenRefresh(newToken);
    });
  }
}

// GeTui 推送通过 getuiflut 插件实现
class GetuiPushController {
  static final GetuiPushController _instance = GetuiPushController._internal();
  factory GetuiPushController() => _instance;

  GetuiPushController._internal();

  Getuiflut? _getuiflut;
  String? _currentAlias;

  Future<void> _initialize(String alias, {void Function(String token)? onTokenRefresh}) async {
    try {
      _currentAlias = alias;
      _getuiflut = Getuiflut();

      print("========== GeTui 初始化开始?==========");
      print("别名: $alias");
      print("AppID: $appID");

      // 先添加事件监听，确保能接收到回调
      print("🔧 开始注册事件监听器...");
      _getuiflut?.addEventHandler(
        onReceiveClientId: (String message) async {
          print("✅ 获取到 ClientID: $message");

          // 绑定别名与 CID (sn 参数使用 ClientID 作为序列号
          try {
            _getuiflut?.bindAlias(alias, message);
            print("✅ 别名绑定成功: $alias -> $message");

            // 通知上层 token 已准备好
            if (onTokenRefresh != null) {
              onTokenRefresh(message);
            }
          } catch (e) {
            print("❌ 别名绑定失败: $e");
          }
        },
        onNotificationMessageArrived: (Map<String, dynamic> message) async {
          print("📬 通知消息到达: $message");
        },
        onNotificationMessageClicked: (Map<String, dynamic> message) async {
          print("👆 通知消息点击: $message");
        },
        onTransmitUserMessageReceive: (Map<String, dynamic> message) async {
          print("📨 透传消息: $message");
        },
        onReceiveOnlineState: (String online) async {
          print("🔌 在线状态: $online");
        },
        onRegisterDeviceToken: (String token) async {
          print("📱 设备 Token: $token");
        },
        onReceivePayload: (Map<String, dynamic> message) async {
          print("📩 收到推送消息: $message");
        },
        onReceiveNotificationResponse: (Map<String, dynamic> response) async {
          print("📮 通知响应: $response");
        },
        onAppLinkPayload: (String payload) async {
          print("🔗 AppLink 载荷: $payload");
        },
        onPushModeResult: (Map<String, dynamic> result) async {
          print("📊 推送模式结果: $result");
        },
        onSetTagResult: (Map<String, dynamic> result) async {
          print("🏷️ ?标签设置结果: $result");
        },
        onAliasResult: (Map<String, dynamic> result) async {
          print("📋 别名操作结果: $result");
        },
        onQueryTagResult: (Map<String, dynamic> result) async {
          print("🔍 标签查询结果: $result");
        },
        onWillPresentNotification: (Map<String, dynamic> notification) async {
          print("📢 即将展示通知: $notification");
        },
        onOpenSettingsForNotification: (Map<String, dynamic> settings) async {
          print("⚙️ 打开通知设置: $settings");
        },
        onGrantAuthorization: (String granted) async {
          print("✅ 授权结果: $granted");
        },
        onLiveActivityResult: (Map<String, dynamic> result) async {
          print("🎬 实时活动结果: $result");
        },
        onRegisterPushToStartTokenResult: (Map<String, dynamic> result) async {
          print("🚀 注册启动推送 Token 结果: $result");
        },
      );
      print("✅ 事件监听器注册完成");

      // 手动启动 SDK（某些情况下需要显式调用）
      try {
        print("📱 尝试初始化 GeTui SDK (Android)...");
        // Android 需要调用 initGetuiSdk
        if (_getuiflut != null) {
          _getuiflut!.initGetuiSdk;
          print("✅ initGetuiSdk 调用完成");
        }

        print("📱 尝试启动 GeTui SDK...");
        _getuiflut?.startSdk(
          appId: appID,
          appKey: appKey,
          appSecret: appSecret,
        );
        print("✅ GeTui SDK 启动调用完成");
      } catch (e) {
        print("⚠️  GeTui SDK 启动失败（可能未注册或已自动启动）: $e");
        if (e.toString().contains('MissingPluginException')) {
          print("提示: getuiflut 原生未注册时会出现此错误，可忽略或检查插件配置");
        }
      }

      // 延迟一下，等待 SDK 初始化（GeTui SDK 需要较长时间）
      print("⏱️  等待 SDK 初始化（2秒）...");
      await Future.delayed(Duration(seconds: 2));
      print("⏱️  延迟完成，开始获取 ClientID");

      // 尝试主动获取 ClientID
      try {
        print("🔍 正在获取 ClientID...");
        final cid = await _getuiflut?.getClientId;
        print("🔍 getClientId 返回值: $cid (类型: ${cid.runtimeType})");
        if (cid != null && cid.isNotEmpty) {
          print("✅ 主动获取到 ClientID: $cid");
          // 绑定别名
          _getuiflut?.bindAlias(alias, cid);
          print("✅ 主动绑定别名: $alias -> $cid");
          if (onTokenRefresh != null) {
            onTokenRefresh(cid);
          }
        } else {
          print("⚠️  ClientID 尚未准备好(值为: $cid)，等待 onReceiveClientId 回调");
        }
      } catch (e) {
        print("⚠️  主动获取 ClientID 失败: $e");
        print("错误详情: ${e.toString()}");
      }

      print("========== GeTui 初始化完成 ==========");
    } catch (e) {
      print("❌ GeTui 初始化失败: $e");
      print("错误堆栈: ${StackTrace.current}");
    }
  }

  Future<void> _unbindAlias() async {
    if (_currentAlias != null && _getuiflut != null) {
      try {
        final cid = await _getuiflut!.getClientId;
        if (cid != null && cid.isNotEmpty) {
          // unbindAlias(alias, sn, isSelf)
          // isSelf: true 表示只解绑当前设备，false 表示解绑所有设备
          _getuiflut!.unbindAlias(_currentAlias!, cid, true);
          print("✅ GeTui 解绑别名成功: $_currentAlias");
        }
        _currentAlias = null;
      } catch (e) {
        print("❌ GeTui 解绑别名失败: $e");
      }
    }
  }

  Future<String?> getClientId() async {
    try {
      return await _getuiflut?.getClientId;
    } catch (e) {
      print("❌ 获取 ClientID 失败: $e");
      return null;
    }
  }
}
