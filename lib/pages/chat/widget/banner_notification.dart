import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import '../../../routes/app_navigator.dart';

class BannerNotification extends StatelessWidget {
  final Message message;
  final double textScaleFactor;

  NotifyBannerElem? get bannerElem {
    if (message.contentType == MessageType.oaNotification) {
      if (message.notificationElem == null || message.notificationElem!.detail == null) {
        return null;
      }
      var notifyContent = NotifyContent.fromJson(jsonDecode(message.notificationElem!.detail!));
      return notifyContent.bannerElem;
    }
    return null;
  }

  const BannerNotification({super.key, 
    required this.message,
    required this.textScaleFactor,
  });

  bool get hasExternalUrl => (bannerElem?.externalUrl != null && bannerElem!.externalUrl.isNotEmpty) || (bannerElem?.articleId != null && bannerElem!.articleId.isNotEmpty);

  Widget _buildPicture() {
    return ImageUtil.networkImage(
      url: bannerElem!.imageUrl,
      fit: BoxFit.cover,
    );
  }

  void _onTapBanner() {
    if (hasExternalUrl) {
      final url = bannerElem!.externalUrl.isNotEmpty ? bannerElem!.externalUrl : bannerElem!.articleId;
      // 判断是否为网页链接
      if (url.startsWith('http://') || url.startsWith('https://')) {
        AppNavigator.startWebViewPage(url: url);
      } else {
        AppNavigator.startArticle(articleId: url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (bannerElem == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        border: Border.all(color: Styles.c_E8EAEF, width: 1),
        borderRadius: BorderRadius.all(Radius.circular(8.r)),
      ),
      child: GestureDetector(
        onTap: _onTapBanner,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部图片
            if (bannerElem!.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8.r),
                  topRight: Radius.circular(8.r),
                ),
                child: AspectRatio(
                  aspectRatio: 2.0,
                  child: _buildPicture(),
                ),
              ),
            
            // 内容区域
            Container(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  if (bannerElem!.title.isNotEmpty)
                    Text(
                      bannerElem!.title,
                      style: Styles.ts_0C1C33_14sp_medium.copyWith(
                        fontSize: (16 * textScaleFactor).sp,
                      ),
                    ),
                  
                  // 副标题
                  if (bannerElem!.description.isNotEmpty) ...[
                    8.verticalSpace,
                    Text(
                      bannerElem!.description,
                      style: Styles.ts_8E9AB0_14sp.copyWith(
                        fontSize: (14 * textScaleFactor).sp,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  // 外链提示
                  if (hasExternalUrl) ...[
                    Divider(
                      color: Styles.c_E8EAEF,
                      height: 20.h,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          StrRes.clickToView,
                          style: Styles.ts_8E9AB0_14sp.copyWith(
                            fontSize: (14 * textScaleFactor).sp,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16.w,
                          color: Styles.c_8E9AB0,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}