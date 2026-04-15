import 'package:flutter/material.dart';
import 'package:openim_common/openim_common.dart';

class ChatAvatar extends StatelessWidget {
  final double size;
  final String? faceUrl;
  final String? nickname;

  const ChatAvatar({
    Key? key,
    required this.size,
    this.faceUrl,
    this.nickname,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: faceUrl != null && faceUrl!.isNotEmpty
          ? Image.network(
              faceUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder();
              },
            )
          : _buildPlaceholder(),
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[300],
      child: Center(
        child: Text(
          nickname?.substring(0, 1).toUpperCase() ?? '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size / 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 