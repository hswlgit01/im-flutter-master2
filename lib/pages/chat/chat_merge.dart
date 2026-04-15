import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:focus_detector_v2/focus_detector_v2.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/widgets/chat/voice_message.dart';

class ChatMerge extends StatelessWidget {
  final Message message;

  const ChatMerge({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return (Scaffold(
        appBar: TitleBar.back(title: "${message.mergeElem?.title}"),
        body: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: ListView.builder(
            itemBuilder: (_, index) {
              final item = message.mergeElem?.multiMessage?[index];

              if (item == null) {
                return const SizedBox();
              }

              return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                          opacity: (index != 0 &&
                                  message.mergeElem?.multiMessage?[index - 1]
                                          .sendID ==
                                      message.mergeElem?.multiMessage?[index]
                                          .sendID)
                              ? 0
                              : 1,
                          child: AvatarView(
                            url: item.senderFaceUrl,
                            text: item.senderNickname,
                          )),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(left: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.senderNickname ?? "",
                                    style: Styles.ts_8E9AB0_13sp,
                                  ),
                                  Text(
                                      IMUtils.getChatTimeline(
                                          item.sendTime!, 'HH:mm:ss'),
                                      style: Styles.ts_8E9AB0_13sp)
                                ],
                              ),
                              SizedBox(
                                height: 5.h,
                              ),
                              _renderItem(item),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                child: Divider(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ));
            },
            itemCount: message.mergeElem?.multiMessage?.length ?? 0,
          ),
        )));
  }

  _renderItem(Message message) {
    if (message.contentType == MessageType.text) {
      return Text(message.textElem?.content ?? "",
          style: Styles.ts_0C1C33_17sp);
    } else if (message.contentType == MessageType.picture) {
      return GestureDetector(
        onTap: () {
          IMUtils.previewPicture(message);
        },
        child: ChatPictureView(
          message: message,
          isISend: false,
        ),
      );
    } else if (message.contentType == MessageType.file) {
      return GestureDetector(
        onTap: () {
          IMUtils.previewFile(message);
        },
        child: ChatFileView(
          message: message,
        ),
      );
    } else if (message.contentType == MessageType.merger) {
      return GestureDetector(
        onTap: () {
          Get.to(ChatMerge(message: message), preventDuplicates: false);
        },
        child: ChatMergeView(
          message: message,
        ),
      );
    } else if (message.contentType == MessageType.quote) {
      return Text(message.quoteElem?.text ?? "", style: Styles.ts_0C1C33_17sp);
    } else if (message.contentType == MessageType.atText) {
      return ChatAtView(message: message);
    } else if (message.isVideoType) {
      return GestureDetector(
        onTap: () {
          IMUtils.previewMediaFile(context: Get.context!, message: message);
        },
        child: ChatVideoView(
          message: message,
          radius: true,
          isISend: false,
        ),
      );
    } else if (message.contentType == MessageType.voice) {
      return GestureDetector(
        onTap: () {
          AudioPlayerManager().play(message);
        },
        child: FocusDetector(
            child: VoiceMessage(
              message: message,
              isISend: false,
            ),
            onForegroundGained: () =>
                AudioPlayerManager().preDownload(message)),
      );
    } else {
      return Text(IMUtils.parseMsg(message), style: Styles.ts_0C1C33_17sp);
    }
  }
}
