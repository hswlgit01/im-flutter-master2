import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class VideoNotity extends StatelessWidget {
  final String text;
  final NotifyVideoElem notifyVideoElem;
  final String? externalUrl;

  const VideoNotity({
    super.key,
    required this.text,
    required this.notifyVideoElem,
    this.externalUrl,
  });

  bool get isExternalUrl => externalUrl != null && externalUrl != '';

  Widget _buildPicture() {
    return ImageUtil.networkImage(
      url: notifyVideoElem.snapshotUrl,
      fit: BoxFit.fitWidth,
    );
  }

  Future previewMediaFile(
      {required BuildContext context,
      bool muted = false,
      bool Function(int)? onAutoPlay,
      ValueChanged<int>? onPageChanged,
      bool onlySave = false}) {
    final sources = MediaSource(
      url: notifyVideoElem.videoUrl,
      thumbnail:
          notifyVideoElem.snapshotUrl?.adjustThumbnailAbsoluteString(960) ?? '',
      file: File(notifyVideoElem.videoPath!),
      isVideo: true,
    );

    final mb = MediaBrowser(
      sources: [sources],
      initialIndex: 0,
      onAutoPlay: (index) => onAutoPlay != null ? onAutoPlay(index) : false,
      muted: muted,
    );
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return mb;
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  previewMediaFile(context: context);
                },
                child: _buildPicture(),
              ),
              Positioned.fill(child: Center(
                child: LayoutBuilder(builder: (_, constraints) {
                  return ImageRes.videoPause.toImage..width = 40.w;
                }),
              ))
            ],
          ),
          8.verticalSpace,
          Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: Styles.c_0C1C33,
            ),
          ),
          if (isExternalUrl) ...[
            Divider(
              color: Styles.c_E8EAEF,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(StrRes.clickToView),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.w,
                  color: Styles.c_8E9AB0,
                )
              ],
            )
          ]
        ],
      ),
    );
  }
}
