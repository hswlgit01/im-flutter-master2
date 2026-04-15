import 'dart:io';

import 'package:flutter/material.dart';
import 'package:openim_common/openim_common.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class H5Container extends StatefulWidget {
  const H5Container(
      {super.key,
      required this.url,
      this.title,
      this.onControllerCreated,
      this.immersive = false});

  final String url;
  final bool immersive;
  final String? title;
  final Function(WebViewController controller)? onControllerCreated;

  @override
  State<H5Container> createState() => _H5ContainerState();
}

class _H5ContainerState extends State<H5Container> {
  late final WebViewController _controller;

  double progress = 0;

  /// 注入状态栏高度到WebView的CSS全局变量
  Future<void> _injectStatusBarHeight() async {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final jsCode = '''
      (function() {
        if (typeof document !== 'undefined') {
          document.documentElement.style.setProperty('--status-bar-height', '${statusBarHeight}px');
          // 也可以注入到window对象中
          window.statusBarHeight = $statusBarHeight;
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(jsCode);
      debugPrint('Status bar height injected: ${statusBarHeight}px');
    } catch (e) {
      debugPrint('Failed to inject status bar height: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    Logger.print('H5Container: ${widget.url}');

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
            setState(() {
              this.progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            // 页面加载完成后注入状态栏高度
            _injectStatusBarHeight();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              debugPrint('blocking navigation to ${request.url}');
              return NavigationDecision.prevent;
            }
            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          },
          onHttpError: (HttpResponseError error) {
            debugPrint('Error occurred on page: ${error.response?.statusCode}');
          },
          onUrlChange: (UrlChange change) {
            debugPrint('url change to ${change.url}');
          },
          onHttpAuthRequest: (HttpAuthRequest request) {},
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse(widget.url));

    if (!Platform.isMacOS) {
      controller.setBackgroundColor(Colors.white);
    }

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;

    // 将控制器回调给外部
    if (widget.onControllerCreated != null) {
      widget.onControllerCreated!(_controller);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Logger.print('H5Container: ${widget.url}');
    return Scaffold(
      appBar: widget.title != null
          ? TitleBar.back(
              title: widget.title,
              backgroundColor: widget.immersive ? Colors.transparent : null,
            )
          : null,
      extendBodyBehindAppBar: widget.immersive,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          progress < 1.0
              ? LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  color: Colors.blue,
                )
              : const SizedBox(),
        ],
      ),
    );
  }
}
