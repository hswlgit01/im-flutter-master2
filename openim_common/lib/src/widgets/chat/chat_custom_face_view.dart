import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatCustomFaceView extends StatelessWidget {
  const ChatCustomFaceView({
    super.key,
    required this.message,
    required this.isISend,
  });

  final Message message;
  final bool isISend;

  @override
  Widget build(BuildContext context) {
    final face = CustomFaceData.fromMessage(message);
    if (face == null) {
      return ChatText(text: StrRes.unsupportedMessage);
    }

    final width = face.displayWidth;
    final height = face.displayHeight;

    return GestureDetector(
      onTap: () {
        IMUtils.previewUrlPicture([
          MediaSource(
            thumbnail: face.url,
            url: face.url,
            tag: message.clientMsgID,
          ),
        ]);
      },
      child: ClipRRect(
        borderRadius: borderRadius(isISend),
        child: ImageUtil.networkImage(
          url: face.url,
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class CustomFaceData {
  const CustomFaceData({
    required this.url,
    this.width,
    this.height,
  });

  final String url;
  final double? width;
  final double? height;

  double get displayWidth {
    final sourceWidth = width ?? pictureWidth;
    return sourceWidth <= 0
        ? pictureWidth
        : sourceWidth.clamp(48.w, 180.w).toDouble();
  }

  double get displayHeight {
    final sourceWidth = width ?? pictureWidth;
    final sourceHeight = height ?? pictureWidth;
    if (sourceWidth <= 0 || sourceHeight <= 0) return displayWidth;
    final scaledHeight = displayWidth * sourceHeight / sourceWidth;
    return scaledHeight.clamp(48.h, 240.h).toDouble();
  }

  // dawn 2026-06-04 修复移动端无法查看收藏图片：兼容 Web 端 FaceMessage 的 JSON/URL 数据格式。
  static CustomFaceData? fromMessage(Message message) {
    final raw = message.faceElem?.data;
    if (raw == null || raw.trim().isEmpty) return null;

    final value = _tryDecode(raw.trim());
    if (value is Map) {
      return _fromMap(Map<String, dynamic>.from(value));
    }

    if (_looksLikeUrl(raw)) {
      return CustomFaceData(url: raw.trim());
    }

    return null;
  }

  static CustomFaceData? _fromMap(Map<String, dynamic> map) {
    final nested = map['data'];
    if (nested is String) {
      final decoded = _tryDecode(nested);
      if (decoded is Map) {
        final face = _fromMap(Map<String, dynamic>.from(decoded));
        if (face != null) return face;
      }
    } else if (nested is Map) {
      final face = _fromMap(Map<String, dynamic>.from(nested));
      if (face != null) return face;
    }

    final url = (map['url'] ??
            map['src'] ??
            map['path'] ??
            map['sourceUrl'] ??
            map['thumbnail'])
        ?.toString();
    if (url == null || url.trim().isEmpty) return null;

    return CustomFaceData(
      url: url.trim(),
      width: _toDouble(map['width'] ?? map['w']),
      height: _toDouble(map['height'] ?? map['h']),
    );
  }

  static Object? _tryDecode(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _looksLikeUrl(String value) {
    final text = value.trim().toLowerCase();
    return text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.startsWith('/');
  }
}
