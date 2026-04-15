import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:openim_common/openim_common.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:openim_common/src/utils/error_handler.dart';
import 'package:dio/io.dart';

var dio = Dio();

class HttpUtil {
  HttpUtil._();

  static bool _isRetrying = false;

  static void init() {
    // 配置忽略证书验证
    // (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
    //   client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    //   return client;
    // };

    dio
      ..interceptors.add(
        TalkerDioLogger(
          settings: const TalkerDioLoggerSettings(
            printRequestHeaders: kDebugMode,
            printRequestData: kDebugMode,
            printResponseMessage: kDebugMode,
            printResponseData: kDebugMode,
            printResponseHeaders: kDebugMode,
          ),
        ),
      )
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioError e, handler) async {
          // 只在服务器确实不可用时触发自动寻路
          if (!_isRetrying && _shouldTriggerAutoRoute(e)) {
            // 开发环境不执行自动寻路重试
//             if (Config.isDevEnv) {
//               print('🔧 开发环境模式：跳过自动寻路重试');
//               return handler.next(e);
//             }
            
            _isRetrying = true;
            try {
              await ApiAutoRoute.onRequestFailed();
              _isRetrying = false;
            } catch (routeError) {
              print('自动寻路失败: $routeError');
              _isRetrying = false;
              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ));

    dio.options.baseUrl = Config.imApiUrl;
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// 判断是否需要触发自动寻路
  static bool _shouldTriggerAutoRoute(DioError e) {
    // 连接错误（服务器不可达）
    if (e.type == DioExceptionType.connectionError) {
      return true;
    }
    
    // 响应错误，只有在服务器返回特定状态码时才触发
    if (e.type == DioExceptionType.badResponse) {
      final statusCode = e.response?.statusCode;
      // 服务器不可用的状态码：502 Bad Gateway, 503 Service Unavailable, 504 Gateway Timeout
      return statusCode == 502 || statusCode == 503 || statusCode == 504;
    }
    
    return false;
  }

  static String get operationID =>
      DateTime.now().millisecondsSinceEpoch.toString();

  static Future post(
    String path, {
    dynamic data,
    bool showErrorToast = true,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      data ??= {};
      options ??= Options();

      // Merge headers: common headers first, then existing headers override
      final mergedHeaders = <String, dynamic>{
        'operationID': operationID,
        'orgId': DataSp.orgId,
        if (Platform.isIOS) 'source': 'ios',
        if (Platform.isAndroid) 'source': 'android',
        ...?options.headers, // Existing headers override (token, Content-Type, etc.)
      };
      options.headers = mergedHeaders;

      var result = await dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      var resp = ApiResp.fromJson(result.data!);
      if (resp.errCode == 0) {
        return resp.data;
      } else {
        if (showErrorToast) {
          ErrorHandler().handleBusinessError(resp.errCode, customMessage: resp.errMsg);
        }
        return Future.error((resp.errCode, resp.errMsg));
      }
    } catch (error) {
      if (error is DioException) {
        ErrorHandler().handleApiError(error);
        final errorMsg = '接口：$path  信息：${error.message}';
        return Future.error(errorMsg);
      }
      return Future.error(error);
    }
  }

  static Future get(
    String path, {
    bool showErrorToast = true,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      options ??= Options();
      options.headers ??= {};
      options.headers!['operationID'] = operationID;
      options.headers!['orgId'] = DataSp.orgId;
      if (Platform.isIOS) {
        options.headers!['source'] = 'ios';
      } else if (Platform.isAndroid) {
        options.headers!['source'] = 'android';
      }

      var result = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      var resp = ApiResp.fromJson(result.data!);
      if (resp.errCode == 0) {
        return resp.data;
      } else {
        if (showErrorToast) {
          ErrorHandler().handleBusinessError(resp.errCode, customMessage: resp.errMsg);
        }
        return Future.error((resp.errCode, resp.errMsg));
      }
    } catch (error) {
      if (error is DioException) {
        ErrorHandler().handleApiError(error);
        final errorMsg = '接口：$path  信息：${error.message}';
        return Future.error(errorMsg);
      }
      return Future.error(error);
    }
  }

  /// 上传图片到 MinIO
  /// 注意：推荐使用 OpenIM SDK 的 uploadFile 方法代替此方法
  static Future<String> uploadImageForMinio({
    required String path,
    bool compress = true,
  }) async {
    try {
      String fileName = path.substring(path.lastIndexOf("/") + 1);

      String? compressPath;
      if (compress) {
        File? compressFile = await IMUtils.compressImageAndGetFile(File(path));
        compressPath = compressFile?.path;
        Logger.print('compressPath: $compressPath');
      }

      final bytes = await File(compressPath ?? path).readAsBytes();
      final mf = MultipartFile.fromBytes(bytes, filename: fileName);

      var formData = FormData.fromMap({
        'operationID': '${DateTime.now().millisecondsSinceEpoch}',
        'fileType': 1,
        'file': mf
      });

      var resp = await dio.post<Map<String, dynamic>>(
        "${Config.imApiUrl}/third/minio_upload",
        data: formData,
        options: Options(headers: {'token': DataSp.imToken}),
      );

      if (resp.data == null) {
        throw Exception('Upload failed: response is null');
      }

      if (resp.data is Map<String, dynamic>) {
        final data = resp.data!['data'];

        if (data == null) {
          throw Exception('Upload failed: data is null');
        }

        if (data is Map<String, dynamic>) {
          final url = data['URL'];
          if (url != null && url is String) {
            return url;
          }
        } else if (data is String) {
          return data;
        }
      }

      throw Exception('Upload failed: unexpected response format');
    } catch (e) {
      Logger.print('uploadImageForMinio error: $e');
      rethrow;
    }
  }

  static Future download(
    String url, {
    required String cachePath,
    CancelToken? cancelToken,
    Function(int count, int total)? onProgress,
  }) {
    return dio.download(
      url,
      cachePath,
      options: Options(
        receiveTimeout: const Duration(minutes: 10),
      ),
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
    );
  }

  static Future saveUrlPicture(
    String url, {
    CancelToken? cancelToken,
    Function(int count, int total)? onProgress,
    VoidCallback? onCompletion,
  }) async {
    EasyLoading.show(status: StrRes.saving);
    
    final name = url.substring(url.lastIndexOf('/') + 1);
    final cachePath = await IMUtils.createTempFile(dir: 'picture', name: name);
    var intervalDo = IntervalDo();

    return download(
      url,
      cachePath: cachePath,
      cancelToken: cancelToken,
      onProgress: (int count, int total) async {
        onProgress?.call(count, total);
        if (total == -1) {
          onCompletion?.call();
          EasyLoading.dismiss();
          intervalDo.drop(
              fun: () async {
                saveFileToGallerySaver(File(cachePath),
                    showTaost: EasyLoading.isShow);
              },
              milliseconds: 1500);
        }
        if (count == total) {
          EasyLoading.dismiss();
          saveFileToGallerySaver(File(cachePath),
              showTaost: EasyLoading.isShow);
        }
      },
    ).catchError((error) {
      EasyLoading.dismiss();
      throw error;
    });
  }

  static Future saveImage(Image image) async {
    var byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData != null) {
      Uint8List uint8list = byteData.buffer.asUint8List();
      var result =
          await ImageGallerySaverPlus.saveImage(Uint8List.fromList(uint8list));
      if (result != null) {
        var tips = StrRes.saveSuccessfully;
        if (Platform.isAndroid) {
          final filePath = result['filePath'].split('//').last;
          tips = '${StrRes.saveSuccessfully}:$filePath';
        }
        IMViews.showToast(tips);
      }
    }
  }

  static Future saveUrlVideo(
    String url, {
    CancelToken? cancelToken,
    Function(int count, int total)? onProgress,
    VoidCallback? onCompletion,
  }) async {
    EasyLoading.show(status: StrRes.saving);
    
    final name = url.substring(url.lastIndexOf('/') + 1);
    final cachePath = await IMUtils.createTempFile(dir: 'video', name: name);

    if (File(cachePath).existsSync()) {
      EasyLoading.dismiss();
      onCompletion?.call();
      return;
    }

    return download(
      url,
      cachePath: cachePath,
      cancelToken: cancelToken,
      onProgress: (int count, int total) async {
        onProgress?.call(count, total);
        if (count == total) {
          EasyLoading.dismiss();
          onCompletion?.call();
          final result = await ImageGallerySaverPlus.saveFile(cachePath);
          if (result != null) {
            var tips = StrRes.saveSuccessfully;
            if (Platform.isAndroid) {
              final filePath = result['filePath'].split('//').last;
              tips = '${StrRes.saveSuccessfully}:$filePath';
            }
            IMViews.showToast(tips);
          }
        }
      },
    ).catchError((error) {
      EasyLoading.dismiss();
      throw error;
    });
  }

  static Future saveFileToGallerySaver(File file,
      {String? name, bool showTaost = true}) async {
    EasyLoading.show(status: StrRes.saving);
    
    Permissions.photos(() async {
      var tips = StrRes.saveSuccessfully;
      Logger.print('saveFileToGallerySaver: ${file.path}');
      final imageBytes = await file.readAsBytes();

      final result =
          await ImageGallerySaverPlus.saveImage(imageBytes, name: name);
      
      EasyLoading.dismiss();
      
      if (result != null && showTaost) {
        if (Platform.isAndroid) {
          final filePath = result['filePath'].split('//').last;
          tips = '${StrRes.saveSuccessfully}:$filePath';
        }
        IMViews.showToast(tips);
      }
    });
  }
}
