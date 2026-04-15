import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class PictureNotity extends StatelessWidget {
  final String text;
  final NotifyPictureElem notifyPictureElem;
  final String? externalUrl;

  const PictureNotity({
    super.key,
    required this.text,
    required this.notifyPictureElem,
    this.externalUrl,
  });

  bool get isExternalUrl => externalUrl != null && externalUrl != '';

  Widget _buildPicture() {
    return ImageUtil.networkImage(
      url: notifyPictureElem.snapshotPicture.url,
      fit: BoxFit.fitWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              IMUtils.previewUrlPicture(
                [
                  MediaSource(
                      thumbnail: notifyPictureElem.snapshotPicture.url,
                      url: notifyPictureElem.bigPicture.url)
                ],
              );
            },
            child: _buildPicture(),
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
