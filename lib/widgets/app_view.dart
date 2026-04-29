import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:focus_detector_v2/focus_detector_v2.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../core/controller/app_controller.dart';
import '../utils/app_log_uploader.dart';

class AppView extends StatefulWidget {
  const AppView({super.key, required this.builder});
  final Widget Function(Locale? locale, TransitionBuilder builder) builder;

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    // 当系统语言发生变化时，如果用户设置的是跟随系统，则更新应用语言
    final languageIndex = DataSp.getLanguage() ?? 0;
    if (languageIndex == 0) {
      // 用户设置为跟随系统
      final appController = Get.find<AppController>();
      final newLocale = appController.getLocale();
      if (newLocale != null && Get.locale != newLocale) {
        Get.updateLocale(newLocale);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(AppLogUploader.instance.flush(reason: state.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      init: AppController(),
      builder: (ctrl) => FocusDetector(
        onForegroundGained: () => ctrl.runningBackground(false),
        onForegroundLost: () => ctrl.runningBackground(true),
        child: ScreenUtilInit(
          designSize: const Size(Config.uiW, Config.uiH),
          minTextAdapt: true,
          splitScreenMode: true,
          fontSizeResolver: (fontSize, _) => fontSize.toDouble(),
          builder: (_, child) => widget.builder(ctrl.getLocale(), _builder()),
        ),
      ),
    );
  }

  static TransitionBuilder _builder() {
    final builder = EasyLoading.init(
      builder: (context, widget) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(Config.textScaleFactor),
          ),
          child: widget!,
        );
      },
    );

    EasyLoading.instance
      ..userInteractions = true
      ..indicatorSize = 50
      ..backgroundColor = Styles.c_0C1C33
      ..indicatorColor = CupertinoColors.systemGrey2
      ..progressColor = CupertinoColors.systemGrey2
      ..progressWidth = 6.0
      ..textColor = Colors.white
      ..loadingStyle = EasyLoadingStyle.custom
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle;
    return builder;
  }
}
