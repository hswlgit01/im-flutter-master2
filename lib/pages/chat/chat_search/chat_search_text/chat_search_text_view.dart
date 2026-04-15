import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

import 'chat_search_text_logic.dart';

class ChatSearchTextPage extends StatelessWidget {
  final logic = Get.find<ChatSearchTextLogic>();

  ChatSearchTextPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.search(
        controller: logic.inputCtrl,
        onChanged: (value) {
          logic.searchText.value = value;
          logic.reset();
          // logic.startSearchMessage();
        },
        onCleared: () {
          logic.searchText.value = "";
          logic.messageList.clear();
        },
      ),
      backgroundColor: Styles.c_FFFFFF,
      body: Obx(() {
        if (logic.searchText.value.isNotEmpty) {
          return SmartRefresher(
            controller: logic.controller,
            onLoading: logic.onLoad,
            enablePullDown: false,
            enablePullUp: true,
            header: IMViews.buildHeader(),
            footer: IMViews.buildFooter(),
            child: ListView.builder(
              itemCount: logic.messageList.length,
              itemBuilder: (_, index) =>
                  _buildItemView(logic.messageList[index]),
            ),
          );
        }
        if (logic.toType == ToType.global) {
          return const SizedBox();
        }
        return _buildInitView();
      }),
    );
  }

  _buildItemView(Message message) {
    return GestureDetector(
      onTap: () => logic.onMessageTap(message),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 7.h, horizontal: 14.w),
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarView(
              url: message.senderFaceUrl,
              text: message.senderNickname,
            ),
            SizedBox(width: 8.w),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      message.senderNickname ?? "",
                      style: Styles.ts_8E9AB0_15sp,
                    ),
                    Text(IMUtils.getChatTimeline(message.sendTime!, 'HH:mm'),
                        style: Styles.ts_8E9AB0_15sp)
                  ],
                ),
                SizedBox(height: 2.h),
                _buildItemText(message),
                SizedBox(height: 2.h),
                Divider(color: Styles.c_E8EAEF)
              ],
            ))
          ],
        ),
      ),
    );
  }

  _buildInitView() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 50.w),
      child: Column(
        children: [
          Text(
            StrRes.quicklyFindChatHistory,
            style: Styles.ts_8E9AB0_15sp,
          ),
          SizedBox(height: 40.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTextButton(
                  text: StrRes.picture,
                  onPressed: () {
                    logic.searchImage();
                  }),
              _buildTextButton(
                  text: StrRes.video,
                  onPressed: () {
                    logic.searchVideo();
                  }),
              _buildTextButton(
                  text: StrRes.file,
                  onPressed: () {
                    logic.searchFile();
                  }),
            ],
          ),
        ],
      ),
    );
  }

  _buildItemText(Message message) {
    final String text = IMUtils.parseMsg(message);
    return Text.rich(
      TextSpan(
        children: _highlightOccurrences(text, logic.searchText.value),
      ),
      style: Styles.ts_0C1C33_17sp,
    );
  }

  List<TextSpan> _highlightOccurrences(String source, String query) {
    if (query.isEmpty || !source.toLowerCase().contains(query.toLowerCase())) {
      return [TextSpan(text: source)];
    }

    final matches = query.toLowerCase().allMatches(source.toLowerCase());
    final result = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        result.add(
          TextSpan(
            text: source.substring(lastMatchEnd, match.start),
          ),
        );
      }

      result.add(
        TextSpan(
          text: source.substring(match.start, match.end),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Styles.c_0089FF, // 高亮颜色
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < source.length) {
      result.add(
        TextSpan(
          text: source.substring(lastMatchEnd, source.length),
        ),
      );
    }

    return result;
  }

  _buildTextButton({required String text, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Text(
        text,
        style: Styles.ts_0089FF_17sp,
      ),
    );
  }
}
