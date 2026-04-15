import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:focus_detector_v2/focus_detector_v2.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/widgets/chat/voice_message.dart';
import 'package:rxdart/rxdart.dart';

import 'chat_notice_view.dart';

double maxWidth = 227.w;
double pictureWidth = 120.w;
double videoWidth = 120.w;
double locationWidth = 220.w;

BorderRadius borderRadius(bool isISend) => BorderRadius.only(
      topLeft: Radius.circular(isISend ? 6.r : 0),
      topRight: Radius.circular(isISend ? 0 : 6.r),
      bottomLeft: Radius.circular(6.r),
      bottomRight: Radius.circular(6.r),
    );

class MsgStreamEv<T> {
  final String id;
  final T value;

  MsgStreamEv({required this.id, required this.value});

  @override
  String toString() {
    return 'MsgStreamEv{msgId: $id, value: $value}';
  }
}

class CustomTypeInfo {
  final Widget customView;
  final bool needBubbleBackground;
  final bool needChatItemContainer;

  CustomTypeInfo(
    this.customView, [
    this.needBubbleBackground = true,
    this.needChatItemContainer = true,
  ]);
}

typedef CustomTypeBuilder = CustomTypeInfo? Function(
  BuildContext context,
  Message message,
);
typedef NotificationTypeBuilder = Widget? Function(
  BuildContext context,
  Message message,
);
typedef ItemViewBuilder = Widget? Function(
  BuildContext context,
  Message message,
);
typedef ItemVisibilityChange = void Function(
  Message message,
  bool visible,
);

class ChatItemView extends StatefulWidget {
  const ChatItemView(
      {Key? key,
      this.mediaItemBuilder,
      this.itemViewBuilder,
      this.customTypeBuilder,
      this.notificationTypeBuilder,
      this.sendStatusSubject,
      this.visibilityChange,
      this.timelineStr,
      this.leftNickname,
      this.leftFaceUrl,
      this.rightNickname,
      this.rightFaceUrl,
      required this.message,
      this.textScaleFactor = 1.0,
      this.isMultiSelectMode = false,
      this.isShowReadStatus = false,
      this.showLeftNickname = true,
      this.showRightNickname = false,
      this.highlightColor,
      this.allAtMap = const {},
      this.patterns = const [],
      this.onTapLeftAvatar,
      this.onTapRightAvatar,
      this.onLongPressRightAvatar,
      this.onVisibleTrulyText,
      this.onFailedToResend,
      this.onClickItemView,
      this.onLongPressLeftAvatar,
      required this.onTapUserProfile,
      this.onMessageOperation,
      this.selectedMessages = const [],
      this.onMessageSelected,
      this.onMentionTap,
      this.messageOperationTypes = const []})
      : super(key: key);
  final ItemViewBuilder? mediaItemBuilder;
  final ItemViewBuilder? itemViewBuilder;
  final CustomTypeBuilder? customTypeBuilder;
  final NotificationTypeBuilder? notificationTypeBuilder;

  final Subject<MsgStreamEv<bool>>? sendStatusSubject;

  final ItemVisibilityChange? visibilityChange;
  final String? timelineStr;
  final String? leftNickname;
  final String? leftFaceUrl;
  final String? rightNickname;
  final String? rightFaceUrl;
  final Message message;
  final Function(String id)? onMentionTap;
  final double textScaleFactor;
  final bool isMultiSelectMode;
  final bool isShowReadStatus;
  final List<Message> selectedMessages;
  final Function(Message message)? onMessageSelected;
  final bool showLeftNickname;
  final bool showRightNickname;
  final List<MessageOperationType> messageOperationTypes;

  /// 长按左头像
  final Function()? onLongPressLeftAvatar;

  final Color? highlightColor;
  final Map<String, String> allAtMap;
  final List<MatchPattern> patterns;
  final Function()? onTapLeftAvatar;
  final Function()? onTapRightAvatar;
  final Function()? onLongPressRightAvatar;
  final Function(String? text)? onVisibleTrulyText;
  final Function()? onClickItemView;
  final ValueChanged<
          ({String userID, String name, String? faceURL, String? groupID})>
      onTapUserProfile;

  final Function()? onFailedToResend;
  final Function(MessageOperationType operationType)? onMessageOperation;
  @override
  State<ChatItemView> createState() => _ChatItemViewState();
}

class _ChatItemViewState extends State<ChatItemView> {
  Message get _message => widget.message;

  bool get _isISend => _message.sendID == OpenIM.iMManager.userID;

  @override
  Widget build(BuildContext context) {
    return FocusDetector(
      child: Container(
        color: widget.highlightColor,
        margin: EdgeInsets.only(bottom: 20.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Center(child: _child),
      ),
      onVisibilityLost: () {
        widget.visibilityChange?.call(widget.message, false);
      },
      onVisibilityGained: () {
        widget.visibilityChange?.call(widget.message, true);
      },
    );
  }

  Widget get _child =>
      widget.itemViewBuilder?.call(context, _message) ?? _buildChildView();

  Widget _buildChildView() {
    Widget? child;
    String? senderNickname;
    String? senderFaceURL;
    bool isBubbleBg = false;
    /* if (_message.isCallType) {
    } else if (_message.isMeetingType) {
    } else if (_message.isDeletedByFriendType) {
    } else if (_message.isBlockedByFriendType) {
    } else if (_message.isEmojiType) {
    } else if (_message.isTagType) {
    }*/
    if (_message.isTextType) {
      isBubbleBg = true;
      child = ChatText(
        text: _message.textElem!.content!,
        patterns: widget.patterns,
        textScaleFactor: widget.textScaleFactor,
        onVisibleTrulyText: widget.onVisibleTrulyText,
      );
    } else if (_message.isVoiceType) {
      isBubbleBg = true;
      child = VoiceMessage(message: _message);
    } else if (_message.contentType == MessageType.atText) {
      isBubbleBg = true;
      child = Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
        ),
        child: ChatAtView(
          message: _message,
          onMentionTap: (id) {
            widget.onMentionTap?.call(id);
          },
        ),
      );
    } else if (_message.isPictureType ||
        _message.contentType == MessageType.file) {
      child = widget.mediaItemBuilder?.call(context, _message) ??
          ChatPictureView(
            isISend: _isISend,
            message: _message,
          );
    } else if (_message.contentType == MessageType.card) {
      child = widget.mediaItemBuilder?.call(context, _message);
    } else if (_message.isNotificationType) {
      if (_message.contentType ==
          MessageType.groupInfoSetAnnouncementNotification) {
        final map = json.decode(_message.notificationElem!.detail!);
        final ntf = GroupNotification.fromJson(map);
        final noticeContent = ntf.group?.notification;
        senderNickname = ntf.opUser?.nickname;
        senderFaceURL = ntf.opUser?.faceURL;
        child = ChatNoticeView(isISend: _isISend, content: noticeContent!);
      } else {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ChatHintTextView(
            message: _message,
            onTapUserProfile: widget.onTapUserProfile,
          ),
        );
      }
    } else if (_message.isCustomType) {
      //add 处理自定义消息类型和文件消息
      final customInfo = widget.customTypeBuilder?.call(context, _message);
      if (customInfo != null) {
        child = customInfo.customView;
        isBubbleBg = customInfo.needBubbleBackground;

        if (!customInfo.needChatItemContainer) {
          return child;
        }
      }
      
    } else if (_message.contentType == MessageType.quote) {
      child = _quoteMessageView(
        context: context,
        message: _message,
        isISend: _message.sendID == OpenIM.iMManager.userID,
      );
    } else if (_message.contentType == MessageType.merger) {
      child = ChatMergeView(message: _message);
    } else if (_message.isVideoType) {
      child = ChatVideoView(
        message: _message,
        isISend: _message.sendID == OpenIM.iMManager.userID,
      );
    }

    senderNickname ??= widget.leftNickname ?? _message.senderNickname;
    senderFaceURL ??= widget.leftFaceUrl ?? _message.senderFaceUrl;

    return child = ChatItemContainer(
      id: _message.clientMsgID!,
      isISend: _isISend,
      leftNickname: senderNickname,
      selectedMessages: widget.selectedMessages,
      onMessageSelected: () => widget.onMessageSelected?.call(_message),
      leftFaceUrl: senderFaceURL,
      rightNickname: widget.rightNickname ?? OpenIM.iMManager.userInfo.nickname,
      rightFaceUrl: widget.rightFaceUrl ?? OpenIM.iMManager.userInfo.faceURL,
      showLeftNickname: widget.showLeftNickname,
      showRightNickname: widget.showRightNickname,
      timelineStr: widget.timelineStr,
      timeStr: IMUtils.getChatTimeline(_message.sendTime!, 'HH:mm:ss'),
      hasRead: _message.isRead!,
      isSending: _message.status == MessageStatus.sending,
      isSendFailed: _message.status == MessageStatus.failed,
      isBubbleBg: child == null ? true : isBubbleBg,
      isMultiSelectMode: widget.isMultiSelectMode,
      isShowReadStatus: widget.isShowReadStatus,
      sendStatusStream: widget.sendStatusSubject,
      onFailedToResend: widget.onFailedToResend,
      onLongPressRightAvatar: widget.onLongPressRightAvatar,
      onTapLeftAvatar: widget.onTapLeftAvatar,
      onTapRightAvatar: widget.onTapRightAvatar,
      onLongPressLeftAvatar: widget.onLongPressLeftAvatar,
      onTapChatBubble: widget.onClickItemView,
      operationTypes: widget.messageOperationTypes,
      onMessageOperation: widget.onMessageOperation,
      child: child ?? ChatText(text: StrRes.unsupportedMessage),
    );
  }

  Widget _quoteMessageView(
      {required Message message,
      required bool isISend,
      required BuildContext context}) {
    final Widget quoteMessageElm;
    switch (message.quoteElem?.quoteMessage?.contentType) {
      case MessageType.text:
        quoteMessageElm = Text(
          "${message.quoteElem?.quoteMessage?.senderNickname}: ${message.quoteElem?.quoteMessage?.textElem?.content}",
          style: Styles.ts_8E9AB0_12sp,
        );
        break;
      case MessageType.quote:
        quoteMessageElm = Text(
          "${message.quoteElem?.quoteMessage?.senderNickname}: ${message.quoteElem?.quoteMessage?.quoteElem?.text}",
          style: Styles.ts_8E9AB0_12sp,
        );
        break;
      case MessageType.picture:
        quoteMessageElm = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${message.quoteElem?.quoteMessage?.senderNickname}: ",
                style: Styles.ts_8E9AB0_12sp),
            SizedBox(
              width: 50.w,
              height: 50.h,
              child: Container(
                child: widget.mediaItemBuilder
                        ?.call(context, message.quoteElem!.quoteMessage!) ??
                    const SizedBox(),
              ),
            )
          ],
        );
        break;
      case MessageType.voice:
        quoteMessageElm = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${message.quoteElem?.quoteMessage?.senderNickname}: ",
                style: Styles.ts_8E9AB0_12sp),
            VoiceMessage(
              message: message.quoteElem!.quoteMessage!,
              isISend: false,
              fontSize: 12,
              iconSize: 12,
            )
          ],
        );
        break;
      case MessageType.file:
        quoteMessageElm = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${message.quoteElem?.quoteMessage?.senderNickname}: ",
                style: Styles.ts_8E9AB0_12sp),
            Container(
              constraints: BoxConstraints(
                maxWidth: 150.w,
              ),
              child: widget.mediaItemBuilder
                      ?.call(context, message.quoteElem!.quoteMessage!) ??
                  const SizedBox(),
            )
          ],
        );
        break;
      case MessageType.video:
        quoteMessageElm = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${message.quoteElem?.quoteMessage?.senderNickname}: ",
                style: Styles.ts_8E9AB0_12sp),
            SizedBox(
              width: 40.w,
              height: 40.h,
              child: GestureDetector(
                onTap: () => IMUtils.previewMediaFile(
                    context: Get.context!,
                    message: message.quoteElem!.quoteMessage!),
                child: ChatVideoView(
                    message: message.quoteElem!.quoteMessage!,
                    radius: true,
                    isISend: true),
              ),
            )
          ],
        );
        break;
      default:
        quoteMessageElm = ChatText(text: StrRes.unsupportedMessage);
    }
    return Column(
      crossAxisAlignment: isISend ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ChatBubble(
          bubbleType: isISend ? BubbleType.send : BubbleType.receiver,
          child: ChatText(text: message.quoteElem?.text ?? ""),
        ),
        GestureDetector(
          onTap: () {
            switch (message.quoteElem?.quoteMessage?.contentType) {
              case MessageType.voice:
                AudioPlayerManager().play(message.quoteElem!.quoteMessage!);
                break;
              default:
            }
          },
          child: Container(
            margin: EdgeInsets.only(top: 4.h),
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: Styles.c_F0F2F6,
              borderRadius: BorderRadius.all(Radius.circular(4.r)),
            ),
            child: quoteMessageElm,
          ),
        ),
      ],
    );
  }
}
