import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'package:vibration/vibration.dart';

/// 消息操作类型枚举
enum MessageOperationType {
  copy(ImageRes.menuCopy),
  revoke(ImageRes.menuRevoke),
  quote(ImageRes.menuReply),
  delete(ImageRes.menuDel),
  forward(ImageRes.menuForward),
  multi(ImageRes.menuMulti),
  ;

  final String image;
  const MessageOperationType(this.image);
}

class ChatItemContainer extends StatelessWidget {
  const ChatItemContainer({
    super.key,
    required this.id,
    this.leftFaceUrl,
    this.rightFaceUrl,
    this.leftNickname,
    this.rightNickname,
    this.timelineStr,
    this.timeStr,
    required this.isBubbleBg,
    required this.isISend,
    required this.hasRead,
    required this.isSending,
    this.isShowReadStatus = false,
    required this.isSendFailed,
    this.isMultiSelectMode = false,
    this.showLeftNickname = true,
    this.showRightNickname = false,
    required this.child,
    this.sendStatusStream,
    this.onTapLeftAvatar,
    this.onTapRightAvatar,
    this.onLongPressRightAvatar,
    this.onLongPressLeftAvatar,
    this.onFailedToResend,
    this.onTapChatBubble,
    required this.operationTypes,
    this.onMessageOperation,
    this.selectedMessages = const [],
    this.onMessageSelected
  });
  final String id;
  final String? leftFaceUrl;
  final String? rightFaceUrl;
  final String? leftNickname;
  final String? rightNickname;
  final String? timelineStr;
  final String? timeStr;
  final bool isBubbleBg;
  final bool isISend;
  final bool hasRead;
  final bool isSending;
  final List<MessageOperationType> operationTypes;
  final bool isSendFailed;
  final bool isMultiSelectMode;
  final List<Message> selectedMessages;
  final Function()? onMessageSelected;
  final bool showLeftNickname;
  final bool showRightNickname;
  final bool isShowReadStatus;
  final Widget child;
  final Stream<MsgStreamEv<bool>>? sendStatusStream;
  final Function()? onTapLeftAvatar;
  final Function()? onTapRightAvatar;
  final Function()? onLongPressRightAvatar;
  final Function()? onLongPressLeftAvatar;
  final Function()? onFailedToResend;
  final Function()? onTapChatBubble;
  final Function(MessageOperationType operationType)? onMessageOperation;

  bool get isSelected => selectedMessages.any((message) => message.clientMsgID == id);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onMessageSelected?.call();
      },
      child: AbsorbPointer(
        absorbing: isMultiSelectMode,
        child: Column(
          children: [
            if (null != timelineStr)
              ChatTimelineView(
                timeStr: timelineStr!,
                margin: EdgeInsets.only(bottom: 20.h),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Visibility(
                    visible: isMultiSelectMode,
                    child: Container(
                      height: 44.h,
                      padding: EdgeInsets.only(right: 10.w),
                      child: Center(
                        child: ChatRadio(checked: isSelected),
                      ),
                    )),
                Expanded(child: isISend ? _buildRightView() : _buildLeftView()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildView(BubbleType type) {
    final menuMaping = {
      MessageOperationType.copy: StrRes.menuCopy,
      MessageOperationType.revoke: StrRes.menuRevoke,
      MessageOperationType.quote: StrRes.menuReply,
      MessageOperationType.delete: StrRes.menuDel,
      MessageOperationType.forward: StrRes.menuForward,
      MessageOperationType.multi: StrRes.menuMulti,
    };
    return Builder(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => onTapChatBubble?.call(),
          onLongPress: () {
            Vibration.vibrate(duration: 20);
            final RenderBox itemBox = context.findRenderObject() as RenderBox;
            itemBox.localToGlobal(Offset.zero);
            openMenu(
                context,
                operationTypes
                    .map((e) {
                      return MenuItem(
                          title: menuMaping[e]!,
                          image: e.image.toImage,
                          onTap: () {
                            onMessageOperation?.call(e);
                          },
                        );
                    })
                    .toList());
          },
          child:
              isBubbleBg ? ChatBubble(bubbleType: type, child: child) : child,
        );
      },
    );
  }

  Widget _buildLeftView() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AvatarView(
            width: 44.w,
            height: 44.h,
            textStyle: Styles.ts_FFFFFF_14sp_medium,
            url: leftFaceUrl,
            text: leftNickname,
            onTap: onTapLeftAvatar,
            onLongPress: onLongPressLeftAvatar,
          ),
          10.horizontalSpace,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ChatNicknameView(
                nickname: showLeftNickname ? leftNickname : null,
                timeStr: timeStr,
              ),
              4.verticalSpace,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChildView(BubbleType.receiver),
                ],
              ),
            ],
          ),
        ],
      );

  Widget _buildRightView() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ChatNicknameView(
                nickname: showRightNickname ? rightNickname : null,
                timeStr: timeStr,
              ),
              4.verticalSpace,
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [                 
                   if (isShowReadStatus && !isSending && !isSendFailed)
                    Container(
                      child: (hasRead ? ImageRes.read : ImageRes.unread).toImage..width = 28.w,
                    ),
                  if (isSendFailed)
                    ChatSendFailedView(
                      id: id,
                      isISend: isISend,
                      onFailedToResend: onFailedToResend,
                      isFailed: isSendFailed,
                      stream: sendStatusStream,
                    ),
                  if (isSending) ChatDelayedStatusView(isSending: isSending),
                  4.horizontalSpace,
                  _buildChildView(BubbleType.send),
                ],
              ),
            ],
          ),
          10.horizontalSpace,
          AvatarView(
            width: 44.w,
            height: 44.h,
            textStyle: Styles.ts_FFFFFF_14sp_medium,
            url: rightFaceUrl,
            text: rightNickname,
            onTap: onTapRightAvatar,
            onLongPress: onLongPressRightAvatar,
          ),
        ],
      );
}

class MenuItem {
  final String title;
  final ImageView image;
  final Function()? onTap;

  MenuItem({
    required this.title,
    required this.image,
    this.onTap,
  });
}

openMenu(BuildContext context, List<MenuItem> items) {
  final RenderBox itemBox = context.findRenderObject() as RenderBox;
  final Offset itemPosition = itemBox.localToGlobal(Offset.zero);
  final appBarHeight = Scaffold.of(context).appBarMaxHeight ?? kToolbarHeight;
  final screenWidth = MediaQuery.of(context).size.width;

  Widget renderMenuItem(ImageView icon, String title) {
    return SizedBox(
      width: 50.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon..width = 24.w,
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(color: Colors.white, fontSize: 10.sp),
                overflow: TextOverflow.ellipsis,
              )
            ],
          ))
        ],
      ),
    );
  }

  final menuWidth = (items.length * 50).w; // Adjust menu width as needed
  final menuHeight = 60.h; // Adjust menu height as needed

  // Adjust the menu position to add some distance from the message
  const double menuMargin = 8.0; // Distance between menu and message
  const double screenMargin = 16.0; // Distance between menu and screen edges

  double dx = itemPosition.dx + (itemBox.size.width / 2) - (menuWidth / 2);
  double dy = itemPosition.dy - menuHeight - menuMargin;

  // Ensure the menu doesn't go beyond the left or right screen boundaries
  if (dx + menuWidth > screenWidth - screenMargin) {
    dx = screenWidth - menuWidth - screenMargin;
  } else if (dx < screenMargin) {
    dx = screenMargin;
  }

  // If there's not enough space above, show the menu below
  if (dy < appBarHeight + screenMargin) {
    dy = itemPosition.dy + itemBox.size.height + menuMargin;
  }

  Navigator.of(context).push(
    MessageMenuPopup(
      postion: Offset(dx, dy),
      child: Stack(
        children: [
          Container(
            height: menuHeight,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
                children: List.generate(items.length, (index) {
              final item = items[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  item.onTap?.call();
                },
                child: renderMenuItem(item.image, item.title),
              );
            })),
          ),
        ],
      ),
    ),
  );
}

class MessageMenuPopup extends PopupRoute {
  final Offset postion;
  final Duration duration;
  final Widget child;

  MessageMenuPopup(
      {super.settings,
      super.filter,
      super.traversalEdgeBehavior,
      required this.postion,
      required this.child,
      this.duration = const Duration(milliseconds: 200)});

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Stack(
      children: [
        Positioned(
          left: postion.dx,
          top: postion.dy,
          child: ScaleTransition(
            scale:
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: child,
          ),
        ),
      ],
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);
}
