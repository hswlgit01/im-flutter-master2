import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewLogic extends GetxController {
  // Your logic here
  late String url;
  late String? title;
  late bool immersive = false;
  WebViewController? controller;

  @override
  void onInit() {
    var arguments = Get.arguments;
    url = arguments['url'] ?? '';
    title = arguments['title'];
    immersive = arguments['immersive'] ?? false;
    super.onInit();
  }
}