import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../widgets/upgrade_view.dart';

mixin UpgradeManger {
  PackageInfo? packageInfo;
  UpgradeInfoV2? upgradeInfoV2;
  var isShowUpgradeDialog = false;
  var isNowIgnoreUpdate = false;
  final subject = PublishSubject<double>();
  final notificationService = NotificationService();

  void closeSubject() {
    subject.close();
  }

  void ignoreUpdate() {
    DataSp.putIgnoreVersion(upgradeInfoV2!.buildVersion! + upgradeInfoV2!.buildVersionNo!);
    Get.back();
  }

  void laterUpdate() {
    isNowIgnoreUpdate = true;
    Get.back();
  }

  getAppInfo() async {
    packageInfo ??= await PackageInfo.fromPlatform();
  }

  void nowUpdate() async {
    final appUrl = upgradeInfoV2?.appURl;

    if (appUrl != null && await canLaunchUrlString(appUrl)) {
      launchUrlString(appUrl);
      return;
    }
  }

  void checkUpdate() async {
    // 直接使用最新版本
    IMViews.showToast('已是最新版本');
    return;
  }

  autoCheckVersionUpgrade() async {
    // 不再自动检查版本更新
    return;
  }

  bool get canUpdate =>
      packageInfo!.version + packageInfo!.buildNumber != upgradeInfoV2!.buildVersion! + upgradeInfoV2!.buildVersionNo!;
}

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AndroidInitializationSettings _androidInitializationSettings =
      const AndroidInitializationSettings('@mipmap/ic_launcher');

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal() {
    if (Platform.isAndroid) {
      init();
    }
  }

  void init() async {
    final InitializationSettings initializationSettings = InitializationSettings(
      android: _androidInitializationSettings,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings, onDidReceiveNotificationResponse: (NotificationResponse response) {
      _handleNotificationClick(response.payload);
    });
  }

  void _handleNotificationClick(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    if (payload.startsWith('chat://')) {
      // 去掉 "chat://" 前缀，剩余部分为 "1/98957112984733516493"
      final pathData = payload.substring(7); // 去掉 "chat://"
      final parts = pathData.split('/');
      
      if (parts.length >= 2) {
        final sessionType = int.tryParse(parts[0]) ?? 0;
        final sourceID = parts[1];
        
        if (sourceID.isNotEmpty && sessionType > 0) {
          final conversationInfo = await OpenIM.iMManager.conversationManager.getOneConversation(sourceID: sourceID, sessionType: sessionType);
          AppNavigator.startChat(conversationInfo: conversationInfo);
        }
      }
    }
  }

  Future createNotification(int count, int i, int id, String status) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails('progress channel', 'progress channel',
        channelDescription: 'progress channel description',
        channelShowBadge: false,
        importance: Importance.max,
        priority: Priority.high,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: count,
        progress: i);
    var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(id, status, '$i%', platformChannelSpecifics, payload: 'item x');

    return;
  }
}
