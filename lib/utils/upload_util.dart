import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart' hide ApiService;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../core/api_service.dart';
import '../utils/log_util.dart';

class UploadUtil {
  static const String TAG = "UploadUtil";
  static const int DEFAULT_CHUNK_SIZE = 5 * 1024 * 1024; // 5MB 默认分片大小
  static const int MAX_FILE_SIZE = 100 * 1024 * 1024; // 100MB 最大文件大小

  // MIME类型映射
  static const Map<String, String> _mimeTypes = {
    'txt': 'text/plain',
    'html': 'text/html',
    'css': 'text/css',
    'js': 'text/javascript',
    'json': 'application/json',
    'csv': 'text/csv',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
    'wav': 'audio/wav',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xml': 'application/xml',
    'zip': 'application/zip',
    'tar': 'application/x-tar',
    '7z': 'application/x-7z-compressed',
    'rar': 'application/vnd.rar',
    'ogg': 'audio/ogg',
    'midi': 'audio/midi',
    'webm': 'audio/webm',
    'avi': 'video/x-msvideo',
    'mpeg': 'video/mpeg',
    'ts': 'video/mp2t',
    'mov': 'video/quicktime',
    'wmv': 'video/x-ms-wmv',
    'flv': 'video/x-flv',
    'mkv': 'video/x-matroska',
    'psd': 'image/vnd.adobe.photoshop',
    'ai': 'application/postscript',
    'eps': 'application/postscript',
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'jsonld': 'application/ld+json',
    'ics': 'text/calendar',
    'sh': 'application/x-sh',
    'php': 'application/x-httpd-php',
    'jar': 'application/java-archive',
  };

  /// 获取MIME类型
  static String getMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase().replaceAll('.', '');
    return _mimeTypes[extension] ?? 'application/octet-stream';
  }

  /// 计算文件MD5哈希（完全仿照JavaScript SparkMD5逻辑）
  static Future<String> calculateFileHash(File file, int partSize) async {
    final fileSize = await file.length();
    final chunks = (fileSize / partSize).ceil();
    final chunkHashList = <String>[];
    
    // 模拟JavaScript的SparkMD5.ArrayBuffer()累积逻辑
    var cumulativeBytes = <int>[];
    
    for (int i = 0; i < chunks; i++) {
      final start = i * partSize;
      final end = (i + 1) * partSize > fileSize ? fileSize : (i + 1) * partSize;
      
      // 读取分片数据
      final chunkBytes = await file.openRead(start, end).toList();
      final chunk = chunkBytes.expand((x) => x).toList();
      
      // 累积所有字节（模拟JavaScript的fileSpark.append()）
      cumulativeBytes.addAll(chunk);
      
      // 计算累积哈希（模拟JavaScript的fileSpark.end()）
      final cumulativeHash = md5.convert(cumulativeBytes).toString();
      chunkHashList.add(cumulativeHash);
    }
    
    // 用逗号连接所有累积哈希，然后计算最终哈希（模拟JavaScript的textSpark逻辑）
    final totalFileHash = chunkHashList.join(',');
    final finalHash = md5.convert(utf8.encode(totalFileHash)).toString();
    
    return finalHash;
  }

  /// 计算分片哈希
  static Future<String> calculateChunkHash(Uint8List chunk) async {
    final digest = md5.convert(chunk);
    return digest.toString();
  }

  /// 获取上传分片大小
  static Future<int> getUploadPartSize(int fileSize) async {
    try {
      final apiService = ApiService();
      final result = await apiService.getUploadPartSize(size: fileSize);
      return result?['size'] ?? DEFAULT_CHUNK_SIZE;
    } catch (e) {
      LogUtil.e(TAG, '获取分片大小失败: $e');
      return DEFAULT_CHUNK_SIZE;
    }
  }

  /// 获取上传URL
  static Future<Map<String, dynamic>> getUploadUrl({
    required String hash,
    required int size,
    required int partSize,
    required int maxParts,
    required String cause,
    required String name,
    required String contentType,
  }) async {
    try {
      final apiService = ApiService();
      final result = await apiService.getUploadUrl(
        hash: hash,
        size: size,
        partSize: partSize,
        maxParts: maxParts,
        cause: cause,
        name: name,
        contentType: contentType,
      );
      return result ?? {};
    } catch (e) {
      LogUtil.e(TAG, '获取上传URL失败: $e');
      rethrow;
    }
  }

  /// 确认上传
  static Future<String> confirmUpload({
    required String uploadID,
    required List<String> parts,
    required String cause,
    required String name,
    required String contentType,
  }) async {
    try {
      final apiService = ApiService();
      final result = await apiService.confirmUpload(
        uploadID: uploadID,
        parts: parts,
        cause: cause,
        name: name,
        contentType: contentType,
      );
      return result?['url'] ?? '';
    } catch (e) {
      LogUtil.e(TAG, '确认上传失败: $e');
      rethrow;
    }
  }

  /// 分片上传主函数（仿照JavaScript逻辑）
  static Future<Map<String, dynamic>> splitUpload({
    required File file,
    Function(double progress)? onProgress,
    String? customFileName,
  }) async {
    try {
      // 检查文件大小
      final fileSize = await file.length();
      if (fileSize > MAX_FILE_SIZE) {
        throw Exception('文件大小超过限制 (${MAX_FILE_SIZE ~/ (1024 * 1024)}MB)');
      }

      // 获取当前用户ID（调试多个来源）
      final openIMUserID = OpenIM.iMManager.userID;
      final dataSpUserID = DataSp.userID;
      LogUtil.i(TAG, '调试用户ID - OpenIM.userID: $openIMUserID, DataSp.userID: $dataSpUserID');
      
      // 优先使用DataSp.userID，如果为空则使用OpenIM的userID
      final userID = dataSpUserID ?? openIMUserID ?? 'anonymous';
      // 确保文件名始终以用户ID开头
      final fileName = customFileName != null 
          ? '${userID}/${customFileName}'
          : '${userID}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final contentType = getMimeType(file.path);
      
      LogUtil.i(TAG, '生成的文件名: $fileName');

      // 获取分片大小
      final partSize = await getUploadPartSize(fileSize);
      final chunks = (fileSize / partSize).ceil();
      
      LogUtil.i(TAG, '开始分片上传: 文件大小=${fileSize ~/ (1024 * 1024)}MB, 分片大小=${partSize ~/ (1024 * 1024)}MB, 分片数量=$chunks');

      // 预先计算所有分片信息和哈希（完全仿照JavaScript SparkMD5逻辑）
      final List<Map<String, int>> chunkGapList = [];
      final List<String> chunkHashList = [];
      
      // 模拟JavaScript的SparkMD5.ArrayBuffer()累积逻辑
      var cumulativeBytes = <int>[];
      
      for (int i = 0; i < chunks; i++) {
        final start = i * partSize;
        final end = (i + 1) * partSize > fileSize ? fileSize : (i + 1) * partSize;
        chunkGapList.add({'start': start, 'end': end});
        
        // 读取分片数据
        final chunkBytes = await file.openRead(start, end).toList();
        final chunk = chunkBytes.expand((x) => x).toList();
        
        // 累积所有字节（模拟JavaScript的fileSpark.append()）
        cumulativeBytes.addAll(chunk);
        
        // 计算累积哈希（模拟JavaScript的fileSpark.end()）
        final cumulativeHash = md5.convert(cumulativeBytes).toString();
        chunkHashList.add(cumulativeHash);
      }
      
      // 计算最终文件哈希（仿照JavaScript SparkMD5逻辑）
      // 用逗号连接所有累积哈希，然后计算最终哈希（模拟JavaScript的textSpark逻辑）
      final totalFileHash = chunkHashList.join(',');
      final finalHash = md5.convert(utf8.encode(totalFileHash)).toString();
      
      LogUtil.i(TAG, '文件哈希计算完成: $finalHash');
      
      // 获取上传URL
      final uploadResult = await getUploadUrl(
        hash: finalHash,
        size: fileSize,
        partSize: partSize,
        maxParts: -1,
        cause: '',
        name: fileName,
        contentType: contentType,
      );

      // 如果直接返回了URL，说明文件已存在
      if (uploadResult['url'] != null) {
        LogUtil.i(TAG, '文件已存在，直接返回URL');
        onProgress?.call(1.0);
        return {'url': uploadResult['url'], 'success': true};
      }

      final upload = uploadResult['upload'];
      if (upload == null) {
        throw Exception('获取上传信息失败');
      }

      final uploadID = upload['uploadID'];
      final sign = upload['sign'];
      final uploadParts = sign['parts'] as List;
      final signQuery = sign['query'];
      final signHeader = sign['header'];

      // 并行上传所有分片
      final dio = Dio();
      final uploadFutures = <Future<void>>[];
      
      for (int i = 0; i < chunks; i++) {
        uploadFutures.add(_uploadChunk(
          dio: dio,
          file: file,
          chunkIndex: i,
          chunkGap: chunkGapList[i],
          partInfo: uploadParts[i],
          signUrl: sign['url'],
          signQuery: signQuery,
          signHeader: signHeader,
        ));
      }

      // 等待所有分片上传完成
      await Future.wait(uploadFutures);
      
      LogUtil.i(TAG, '所有分片上传完成');
      onProgress?.call(0.9);

      // 确认上传
      final apiService = ApiService();
      final confirmResult = await apiService.confirmUpload(
        uploadID: uploadID,
        parts: chunkHashList,
        cause: '',
        name: fileName,
        contentType: contentType,
      );

      final finalUrl = confirmResult?['url'] ?? '';
      LogUtil.i(TAG, '分片上传完成: $finalUrl');
      onProgress?.call(1.0);

      return {
        'url': finalUrl,
        'success': true,
        'fileName': fileName,
        'fileSize': fileSize,
      };
    } catch (e) {
      LogUtil.e(TAG, '分片上传失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 上传单个分片
  static Future<void> _uploadChunk({
    required Dio dio,
    required File file,
    required int chunkIndex,
    required Map<String, int> chunkGap,
    required Map<String, dynamic> partInfo,
    required String signUrl,
    required List<dynamic>? signQuery,
    required List<dynamic>? signHeader,
  }) async {
    try {
      // 获取分片上传信息
      final url = partInfo['url'] ?? signUrl;
      final query = partInfo['query'] ?? signQuery;
      final header = partInfo['header'] ?? signHeader;

      // 构建请求URL
      final uri = Uri.parse(url);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      
      if (signQuery != null) {
        for (final item in signQuery) {
          queryParams[item['key']] = item['values'][0];
        }
      }
      if (query != null) {
        for (final item in query) {
          queryParams[item['key']] = item['values'][0];
        }
      }
      
      final requestUrl = uri.replace(queryParameters: queryParams).toString();

      // 构建请求头
      final headers = <String, String>{};
      
      if (signHeader != null) {
        for (final item in signHeader) {
          headers[item['key']] = item['values'][0];
        }
      }
      if (header != null) {
        for (final item in header) {
          headers[item['key']] = item['values'][0];
        }
      }
      
      final chunkSize = chunkGap['end']! - chunkGap['start']!;
      headers['Content-Length'] = chunkSize.toString();

      // 读取分片数据
      final chunk = await file.openRead(chunkGap['start']!, chunkGap['end']!).toList();
      final chunkData = Uint8List.fromList(chunk.expand((x) => x).toList());

      // 上传分片
      final response = await dio.put(
        requestUrl,
        data: chunkData,
        options: Options(headers: headers),
      );

      if (response.statusCode != 200) {
        throw Exception('分片 ${chunkIndex + 1} 上传失败: ${response.statusCode}');
      }

      LogUtil.i(TAG, '分片 ${chunkIndex + 1} 上传完成');
    } catch (e) {
      LogUtil.e(TAG, '分片 ${chunkIndex + 1} 上传失败: $e');
      rethrow;
    }
  }

  /// 简单文件上传（小文件）
  static Future<Map<String, dynamic>> simpleUpload({
    required File file,
    Function(double progress)? onProgress,
    String? customFileName,
  }) async {
    try {
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) { // 10MB以下使用简单上传
        return await splitUpload(
          file: file,
          onProgress: onProgress,
          customFileName: customFileName,
        );
      }

      // 获取当前用户ID（调试多个来源）
      final openIMUserID = OpenIM.iMManager.userID;
      final dataSpUserID = DataSp.userID;
      LogUtil.i(TAG, '调试用户ID - OpenIM.userID: $openIMUserID, DataSp.userID: $dataSpUserID');
      
      // 优先使用DataSp.userID，如果为空则使用OpenIM的userID
      final userID = dataSpUserID ?? openIMUserID ?? 'anonymous';
      // 确保文件名始终以用户ID开头
      final fileName = customFileName != null 
          ? '${userID}/${customFileName}'
          : '${userID}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final contentType = getMimeType(file.path);
      
      LogUtil.i(TAG, '生成的文件名: $fileName');

      // 对于简单上传，也使用累积MD5逻辑保持一致（作为单个分片）
      final fileBytes = await file.readAsBytes();
      
      // 模拟JavaScript的SparkMD5逻辑：单个分片的累积hash
      final chunkHash = md5.convert(fileBytes).toString();
      final chunkHashList = [chunkHash];
      
      // 用逗号连接所有累积哈希，然后计算最终哈希（模拟JavaScript的textSpark逻辑）
      final totalFileHash = chunkHashList.join(',');
      final fileHash = md5.convert(utf8.encode(totalFileHash)).toString();

      // 获取上传URL
      final uploadResult = await getUploadUrl(
        hash: fileHash,
        size: fileSize,
        partSize: fileSize,
        maxParts: 1,
        cause: '',
        name: fileName,
        contentType: contentType,
      );

      // 如果直接返回了URL，说明文件已存在
      if (uploadResult['url'] != null) {
        onProgress?.call(1.0);
        return {'url': uploadResult['url'], 'success': true};
      }

      final upload = uploadResult['upload'];
      if (upload == null) {
        throw Exception('获取上传信息失败');
      }

      final sign = upload['sign'];
      final uploadParts = sign['parts'] as List;
      final signQuery = sign['query'];
      final signHeader = sign['header'];
      
      // 获取第一个分片的上传信息
      final partInfo = uploadParts[0];
      final url = partInfo['url'];
      final query = partInfo['query'] ?? signQuery;
      final header = partInfo['header'] ?? signHeader;

      // 构建请求URL
      String requestUrl = url;
      if (query != null) {
        final uri = Uri.parse(url);
        final queryParams = Map<String, String>.from(uri.queryParameters);
        for (final item in query) {
          queryParams[item['key']] = item['values'][0];
        }
        requestUrl = uri.replace(queryParameters: queryParams).toString();
      }

      // 构建请求头
      final headers = <String, String>{
        'Content-Length': fileSize.toString(),
      };
      if (header != null) {
        for (final item in header) {
          headers[item['key']] = item['values'][0];
        }
      }

      // 上传文件
      final dio = Dio();
      // fileBytes 已经在前面计算哈希时读取了，这里直接使用
      
      onProgress?.call(0.5);
      
      final response = await dio.put(
        requestUrl,
        data: fileBytes,
        options: Options(headers: headers),
      );

      if (response.statusCode != 200) {
        throw Exception('文件上传失败: ${response.statusCode}');
      }

      onProgress?.call(0.8);

      // 确认上传获取最终URL
      final uploadID = upload['uploadID'];
      
      final apiService = ApiService();
      final confirmResult = await apiService.confirmUpload(
        uploadID: uploadID,
        parts: chunkHashList,
        cause: '',
        name: fileName,
        contentType: contentType,
      );

      final finalUrl = confirmResult?['url'] ?? '';
      onProgress?.call(1.0);

      return {
        'url': finalUrl,
        'success': true,
        'fileName': fileName,
        'fileSize': fileSize,
      };
    } catch (e) {
      LogUtil.e(TAG, '简单上传失败: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
} 