import 'package:flutter/widgets.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';

class ChatSearchPan extends StatelessWidget {
  final ConversationInfo conversationInfo;
  const ChatSearchPan({super.key, required this.conversationInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(6.r),
      ),
      padding: EdgeInsets.only(top: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              StrRes.chatContent,
              style: TextStyle(fontSize: 16, color: Styles.c_000000),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSearchItemView(
                  text: StrRes.search,
                  image: ImageRes.chatSearch.toImage,
                  onTap: searchText),
              _buildSearchItemView(
                  text: StrRes.picture,
                  image: ImageRes.chatSearchPic.toImage,
                  onTap: searchImage),
              _buildSearchItemView(
                  text: StrRes.video,
                  image: ImageRes.chatSearchVideo.toImage,
                  onTap: searchVideo),
              _buildSearchItemView(
                  text: StrRes.file,
                  image: ImageRes.chatSearchFile.toImage,
                  onTap: searchFile),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSearchItemView(
      {required String text, required ImageView image, Function()? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Column(
          children: [
            image
              ..width = 30.w
              ..height = 30.h,
            2.verticalSpace,
            Text(
              text,
              style: TextStyle(fontSize: 13, color: Styles.c_8E9AB0),
            )
          ],
        ),
      ),
    );
  }

  searchText() {
    AppNavigator.startChatSearchText(conversationInfo);
  }

  searchImage() {
    AppNavigator.startChatSearchImage(conversationInfo);
  }

  searchVideo() {
    AppNavigator.startChatSearchVideo(conversationInfo);
  }

  searchFile() {
    AppNavigator.startChatSearchFile(conversationInfo);
  }
}
