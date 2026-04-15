import 'dart:io';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'upload_util.dart';
import '../widgets/upload_progress_dialog.dart';
import 'log_util.dart';

class FileUploadHelper {
  static const String TAG = "FileUploadHelper";

  /// 上传图片文件
  static Future<String?> uploadImage({
    required String imagePath,
    String? customFileName,
    bool showProgress = true,
    String? progressTitle,
    String? progressMessage,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $imagePath');
      }

      if (showProgress) {
        UploadProgressDialog.show(
          title: progressTitle ?? '上传中',
          message: progressMessage ?? '正在上传图片...',
          progress: 0.0,
        );
      }

      final result = await UploadUtil.simpleUpload(
        file: file,
        onProgress: (progress) {
          if (showProgress) {
            UploadProgressDialog.updateProgress(
              progress: progress,
              message: '${progressMessage ?? '正在上传图片...'} (${(progress * 100).toStringAsFixed(1)}%)',
            );
          }
          LogUtil.i(TAG, '图片上传进度: ${(progress * 100).toStringAsFixed(1)}%');
        },
        customFileName: customFileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (showProgress) {
        UploadProgressDialog.close();
      }

      if (result['success'] == true && result['url'] != null) {
        LogUtil.i(TAG, '图片上传成功: ${result['url']}');
        return result['url'];
      } else {
        throw Exception(result['error'] ?? '图片上传失败');
      }
    } catch (e) {
      if (showProgress) {
        UploadProgressDialog.close();
      }
      LogUtil.e(TAG, '图片上传失败: $e');
      rethrow;
    }
  }

  /// 上传视频文件
  static Future<String?> uploadVideo({
    required String videoPath,
    String? customFileName,
    bool showProgress = true,
    String? progressTitle,
    String? progressMessage,
  }) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $videoPath');
      }

      if (showProgress) {
        UploadProgressDialog.show(
          title: progressTitle ?? '上传中',
          message: progressMessage ?? '正在上传视频...',
          progress: 0.0,
        );
      }

      final result = await UploadUtil.splitUpload(
        file: file,
        onProgress: (progress) {
          if (showProgress) {
            UploadProgressDialog.updateProgress(
              progress: progress,
              message: '${progressMessage ?? '正在上传视频...'} (${(progress * 100).toStringAsFixed(1)}%)',
            );
          }
          LogUtil.i(TAG, '视频上传进度: ${(progress * 100).toStringAsFixed(1)}%');
        },
        customFileName: customFileName ?? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      if (showProgress) {
        UploadProgressDialog.close();
      }

      if (result['success'] == true && result['url'] != null) {
        LogUtil.i(TAG, '视频上传成功: ${result['url']}');
        return result['url'];
      } else {
        throw Exception(result['error'] ?? '视频上传失败');
      }
    } catch (e) {
      if (showProgress) {
        UploadProgressDialog.close();
      }
      LogUtil.e(TAG, '视频上传失败: $e');
      rethrow;
    }
  }

  /// 上传任意文件
  static Future<String?> uploadFile({
    required String filePath,
    String? customFileName,
    bool showProgress = true,
    String? progressTitle,
    String? progressMessage,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }

      final fileSize = await file.length();
      final useSplitUpload = fileSize > 10 * 1024 * 1024; // 10MB以上使用分片上传

      if (showProgress) {
        UploadProgressDialog.show(
          title: progressTitle ?? '上传中',
          message: progressMessage ?? '正在上传文件...',
          progress: 0.0,
        );
      }

      final result = useSplitUpload
          ? await UploadUtil.splitUpload(
              file: file,
              onProgress: (progress) {
                if (showProgress) {
                  UploadProgressDialog.updateProgress(
                    progress: progress,
                    message: '${progressMessage ?? '正在上传文件...'} (${(progress * 100).toStringAsFixed(1)}%)',
                  );
                }
                LogUtil.i(TAG, '文件上传进度: ${(progress * 100).toStringAsFixed(1)}%');
              },
              customFileName: customFileName,
            )
          : await UploadUtil.simpleUpload(
              file: file,
              onProgress: (progress) {
                if (showProgress) {
                  UploadProgressDialog.updateProgress(
                    progress: progress,
                    message: '${progressMessage ?? '正在上传文件...'} (${(progress * 100).toStringAsFixed(1)}%)',
                  );
                }
                LogUtil.i(TAG, '文件上传进度: ${(progress * 100).toStringAsFixed(1)}%');
              },
              customFileName: customFileName,
            );

      if (showProgress) {
        UploadProgressDialog.close();
      }

      if (result['success'] == true && result['url'] != null) {
        LogUtil.i(TAG, '文件上传成功: ${result['url']}');
        return result['url'];
      } else {
        throw Exception(result['error'] ?? '文件上传失败');
      }
    } catch (e) {
      if (showProgress) {
        UploadProgressDialog.close();
      }
      LogUtil.e(TAG, '文件上传失败: $e');
      rethrow;
    }
  }

  /// 批量上传文件
  static Future<List<String>> uploadFiles({
    required List<String> filePaths,
    bool showProgress = true,
    String? progressTitle,
    String? progressMessage,
  }) async {
    final List<String> uploadedUrls = [];
    final totalFiles = filePaths.length;

    for (int i = 0; i < filePaths.length; i++) {
      try {
        if (showProgress) {
          UploadProgressDialog.show(
            title: progressTitle ?? '批量上传中',
            message: '${progressMessage ?? '正在上传文件...'} (${i + 1}/$totalFiles)',
            progress: i / totalFiles,
          );
        }

        final url = await uploadFile(
          filePath: filePaths[i],
          showProgress: false, // 不显示单个文件的进度
        );

        if (url != null) {
          uploadedUrls.add(url);
        }
      } catch (e) {
        LogUtil.e(TAG, '批量上传文件失败: ${filePaths[i]}, 错误: $e');
        // 继续上传其他文件
      }
    }

    if (showProgress) {
      UploadProgressDialog.close();
    }

    return uploadedUrls;
  }

  /// 检查文件大小是否超过限制
  static bool isFileSizeExceeded(int fileSize, int maxSizeMB) {
    return fileSize > maxSizeMB * 1024 * 1024;
  }

  /// 获取文件大小的可读字符串
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
  }
} 