import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import './logic.dart';

class WebViewPage extends StatelessWidget {
  final logic = Get.find<WebViewLogic>();
  bool _isHandlingPop = false;

  WebViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isHandlingPop) return;
        _isHandlingPop = true;

        try {
          if (logic.controller == null) {
            Get.back(result: result);
            return;
          }
          if (await logic.controller!.canGoBack()) {
            logic.controller?.goBack();
          } else {
            Get.back(result: result);
          }
        } finally {
          _isHandlingPop = false;
        }
      },
      child: H5Container(
          url: logic.url,
          title: logic.title,
          immersive: logic.immersive,
          onControllerCreated: (controller) => logic.controller = controller),
    );
  }
}
