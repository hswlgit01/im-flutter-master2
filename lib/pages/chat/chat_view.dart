import 'dart:convert';

import 'package:chat_listview/chat_listview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/pages/chat/widget/group_card_message_view.dart';
import 'package:openim/pages/chat/widget/refund_notification.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../routes/app_pages.dart';
import '../../utils/logger.dart';
import 'chat_logic.dart';
import 'voice_record_bar.dart';
import 'widget/chat_luck_money_item_view.dart';
import 'widget/chat_transfer_item_view.dart';
import 'widget/card_message_view.dart';

class ChatPage extends StatelessWidget {
  /// 聊天逻辑控制器
  final logic = Get.find<ChatLogic>(tag: GetTags.chat);

  ChatPage({super.key});

  List<MessageOperationType> _messageOperationTypes(Message message) {
    final Map<MessageOperationType, bool> operationTypeMapping = {
      MessageOperationType.revoke: logic.isAdminOrOwner ||
          !message.isCustomType &&
              (DateTime.now().millisecondsSinceEpoch - message.createTime!)
                      .abs() <=
                  2 * 60 * 1000 &&
              message.sendID == OpenIM.iMManager.userID,
      MessageOperationType.copy: message.isTextType 
      || message.contentType == MessageType.atText 
      || message.contentType == MessageType.quote
      || message.isPictureType,
      MessageOperationType.forward: !message.isCustomType,
      MessageOperationType.delete: true,
      MessageOperationType.quote: message.isTextType ||
          message.isPictureType ||
          message.isVideoType ||
          message.isVoiceType ||
          message.isFileType ||
          message.contentType == MessageType.quote,
      MessageOperationType.multi: true,
    };

    List<MessageOperationType> operationTypes = operationTypeMapping.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    return operationTypes;
  }

  Widget _buildItemView(Message message) {
    // 在Obx包装器内部，这些值会自动响应变化
    return ChatItemView(
      key: logic.itemKey(message),
      message: message,
      isMultiSelectMode: logic.isMultiSelectMode.value,
      selectedMessages: logic.selectedMessages.value,
      onMessageSelected: (message) => logic.selectMessage(message),
      textScaleFactor: logic.scaleFactor.value,
      allAtMap: logic.getAtMapping(message),
      timelineStr: logic.getShowTime(message),
      sendStatusSubject: logic.sendStatusSub,
      leftNickname: logic.getNewestNickname(message),
      leftFaceUrl: logic.getNewestFaceURL(message),
      rightNickname: logic.senderName,
      rightFaceUrl: OpenIM.iMManager.userInfo.faceURL,
      showLeftNickname: !logic.isSingleChat,
      showRightNickname: !logic.isSingleChat,
      isShowReadStatus: logic.isShowReadStatus(message) && logic.isSingleChat,
      highlightColor: message.clientMsgID == logic.searchMessage?.clientMsgID
          ? Styles.c_0089FF_opacity10
          : Colors.transparent,
      onFailedToResend: () => logic.failedResend(message),
      messageOperationTypes: _messageOperationTypes(message),
      onMentionTap: (id) =>
          AppNavigator.startUserProfilePane(userID: id, groupID: logic.groupID),
      onClickItemView: () => logic.parseClickEvent(message),
      onLongPressLeftAvatar: () => logic.onLongPressLeftAvatar(message),
      onMessageOperation: (type) => logic.performMessageAction(type, message),
      visibilityChange: (msg, visible) {
        logic.markMessageAsRead(message, visible);
        if (visible) {
          logic.preDownloadAudio(message);
        }
      },
      onLongPressRightAvatar: () {},
      onTapLeftAvatar: () {
        logic.onTapLeftAvatar(message);
      },
      onVisibleTrulyText: (text) {
        logic.copyTextMap[message.clientMsgID] = text;
      },
      customTypeBuilder: _buildCustomTypeItemView,
      patterns: <MatchPattern>[
        MatchPattern(
          type: PatternType.email,
          onTap: logic.clickLinkText,
        ),
        MatchPattern(
          type: PatternType.url,
          onTap: logic.clickLinkText,
        ),
        MatchPattern(
          type: PatternType.mobile,
          onTap: logic.clickLinkText,
        ),
        MatchPattern(
          type: PatternType.tel,
          onTap: logic.clickLinkText,
        ),
      ],
      mediaItemBuilder: (context, message) {
        return _buildMediaItem(context, message);
      },
      onTapUserProfile: handleUserProfileTap,
    );
  }

  void handleUserProfileTap(
      ({
        String userID,
        String name,
        String? faceURL,
        String? groupID
      }) userProfile) {
    final userInfo = UserInfo(
        userID: userProfile.userID,
        nickname: userProfile.name,
        faceURL: userProfile.faceURL);
    logic.viewUserInfo(userInfo);
  }

  Widget? _buildCardItem(BuildContext context, Message message) {
    if (message.contentType != MessageType.card) {
      return null;
    }

    return GestureDetector(
      onTap: () async {
        try {
          if (message.contentType == MessageType.file) {
            // 处理文件点击事件
            final fileElem = message.fileElem;
            if (fileElem != null) {
              IMViews.showToast('文件: ${fileElem.fileName}');
            }
          } else {
            IMUtils.previewMediaFile(
                context: context,
                message: message,
                onAutoPlay: (index) {
                  return !logic.playOnce;
                },
                muted: logic.rtcIsBusy,
                onPageChanged: (index) {
                  logic.playOnce = true;
                }).then((value) {
              logic.playOnce = false;
            });
          }
        } catch (e) {
          IMViews.showToast(e.toString());
        }
      },
      child: Hero(
        tag: message.clientMsgID!,
        child: _buildMediaContent(message),
        placeholderBuilder:
            (BuildContext context, Size heroSize, Widget child) => child,
      ),
    );
  }

  Widget? _buildMediaItem(BuildContext context, Message message) {
    if (message.contentType != MessageType.picture &&
        message.contentType != MessageType.video &&
        message.contentType != MessageType.file &&
        message.contentType != MessageType.card) {
      return null;
    }

    if (message.contentType == MessageType.card) {
      return CardMessageView(
        message: message,
        isSelf: message.sendID == OpenIM.iMManager.userID,
        onTap: () => logic.parseClickEvent(message),
      );
    }

    return GestureDetector(
      onTap: () async {
        try {
          if (message.contentType == MessageType.file) {
            // 处理文件点击事件
            final fileElem = message.fileElem;
            if (fileElem != null) {
              IMViews.showToast('文件: ${fileElem.fileName}');
            }
          } else {
            IMUtils.previewMediaFile(
                context: context,
                message: message,
                onAutoPlay: (index) {
                  return !logic.playOnce;
                },
                muted: logic.rtcIsBusy,
                onPageChanged: (index) {
                  logic.playOnce = true;
                }).then((value) {
              logic.playOnce = false;
            });
          }
        } catch (e) {
          IMViews.showToast(e.toString());
        }
      },
      child: Hero(
        tag: message.clientMsgID!,
        child: _buildMediaContent(message),
        placeholderBuilder:
            (BuildContext context, Size heroSize, Widget child) => child,
      ),
    );
  }

  Widget _buildMediaContent(Message message) {
    final isOutgoing = message.sendID == OpenIM.iMManager.userID;

    if (message.isVideoType) {
      return const SizedBox();
    } else if (message.contentType == MessageType.file) {
      // 构建文件消息视图
      final fileElem = message.fileElem;
      if (fileElem != null) {
        return GestureDetector(
          onTap: () {
            // 直接使用IMUtils打开文件
            IMUtils.previewFile(message);
          },
          child: Container(
            padding: EdgeInsets.all(8.w),
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(
                color: Colors.grey.withOpacity(0.5),
                width: 1,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Icon(
                    Icons.insert_drive_file,
                    color: Colors.grey,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fileElem.fileName ?? '未知文件',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Text(
                            _formatFileSize(fileElem.fileSize ?? 0),
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12.sp,
                            ),
                          ),
                          if (fileElem.filePath == null ||
                              fileElem.filePath!.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(left: 4.w),
                              child: Icon(
                                Icons.download,
                                color:
                                    isOutgoing ? Styles.c_0089FF : Colors.grey,
                                size: 14.w,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return ChatPictureView(
      isISend: isOutgoing,
      message: message,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  void _startTransfer() {
    final walletController = Get.find<WalletController>();
    walletController.checkWalletetActivated(() {
      if (logic.isSingleChat) {
        Get.toNamed(
          AppRoutes.transfer,
          arguments: {
            'receiverID': logic.userID,
            'chatLogic': logic,
          },
        );
      }
    });
  }

  CustomTypeInfo? _buildCustomTypeItemView(_, Message message) {
    try {
      // ILogger.d('消息fileElem: ${message.消息fileElem}');

      final data = IMUtils.parseCustomMessage(message);

      // ILogger.d('自定义消息------------$data');
      if (null != data) {
        final viewType = data['customType'] ?? data['viewType'];
        // 将 CustomMessageType.recover 类型的消息作为通知处理
        if (viewType == CustomMessageType.recover) {
          // 已经在 ChatListView.itemBuilder 中直接处理了,这里返回 null
          return null;
        } else if (viewType == CustomMessageType.call) {
          final type = data['type'];
          final content = data['content'];
          final view = ChatCallItemView(type: type, content: content);
          return CustomTypeInfo(view);
        } else if (viewType == CustomMessageType.deletedByFriend ||
            viewType == CustomMessageType.blockedByFriend) {
          final view = ChatFriendRelationshipAbnormalHintView(
            name: logic.nickname.value,
            onTap: logic.sendFriendVerification,
            blockedByFriend: viewType == CustomMessageType.blockedByFriend,
            deletedByFriend: viewType == CustomMessageType.deletedByFriend,
          );
          return CustomTypeInfo(view, false, false);
        } else if (viewType == CustomMessageType.removedFromGroup) {
          return CustomTypeInfo(
            StrRes.removedFromGroupHint.toText..style = Styles.ts_8E9AB0_12sp,
            false,
            false,
          );
        } else if (viewType == CustomMessageType.groupDisbanded) {
          return CustomTypeInfo(
            StrRes.groupDisbanded.toText..style = Styles.ts_8E9AB0_12sp,
            false,
            false,
          );
        } else if (viewType == CustomMessageType.luckMoney) {
          final view = ChatLuckMoneyItemView(data: data);
          return CustomTypeInfo(view, false, true);
        } else if (viewType == CustomMessageType.transfer) {
          // 转账消息
          final view = ChatTransferItemView(
            data: data,
            onTransferReceived: (success, newStatus) {
              if (success) {
                // 发送收款成功消息
                final transferData = {
                  'customType': CustomMessageType.transfer,
                  'data': {
                    'msg_id': data['msg_id'],
                    'create_time': DateTime.now().millisecondsSinceEpoch,
                    'creator': OpenIM.iMManager.userID,
                    'room_id': logic.conversationInfo.conversationID,
                    'total_amount': data['total_amount'],
                    'code': 'IM_CHART_TRANSFER',
                    'currency': data['currency'],
                    'sender': OpenIM.iMManager.userID,
                    'belong_to': data['belong_to'],
                    'expire_time': data['expire_time'],
                    'remark': data['remark'],
                    'extension': {},
                    'isReceived': true,
                    'status': 'completed'
                  }
                };

                final jsonData = jsonEncode(transferData);
                logic.sendCustomMsg(
                  data: jsonData,
                  extension: '',
                  description: '[转账]',
                );
              }
            },
          );
          return CustomTypeInfo(view, false, true);
        } else if (viewType == CustomMessageType.groupCard) {
          final view = GroupCardMessageView(
              message: message,
              isSelf: message.sendID == OpenIM.iMManager.userID);
          return CustomTypeInfo(view, false, true);
        } else if (viewType == CustomMessageType.refundNotification) {
          final view = RefundNotification(message: message);
          return CustomTypeInfo(view, false, true);
        } else if (viewType == CustomMessageType.infoChange) {
          // 组织/权限/CanSendFreeMsg 变更通知（Free-IM-Chat organization 模块）
          final content = data['content']?.toString() ?? '组织/权限通知';
          return CustomTypeInfo(
            content.toText..style = Styles.ts_8E9AB0_12sp,
            false,
            false,
          );
        } else if (viewType == CustomMessageType.unknown) {
          // 未知 customType 兜底：展示从 data 提取的 content，避免「暂不支持的消息类型」
          final content = data['content']?.toString() ?? StrRes.otherMessage;
          return CustomTypeInfo(
            content.toText..style = Styles.ts_8E9AB0_12sp,
            false,
            false,
          );
        }
      }
      return null;
    } catch (e) {
      ILogger.d(e);
    }
  }

  Widget? get _groupCallHintView => null;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: logic.willPop(),
      child: Obx(() {
        final _length = logic.customChatListViewController.rxList.length;
        final quoteContent = logic.quote.value != null
            ? IMUtils.createSummary(logic.quote.value!)
            : null;
        return Scaffold(
            backgroundColor: Styles.c_F0F2F6,
            resizeToAvoidBottomInset: false,
            appBar: TitleBar.chat(
              title: logic.nickname.value,
              member: logic.memberStr,
              isMultiModel: logic.isMultiSelectMode.value,
              showCallBtn: !logic.isGroupChat,
              onCloseMultiModel: logic.exit,
              onClickMoreBtn: logic.chatSetup,
              onClickCallBtn: logic.isGroupChat ? null : logic.call,
            ),
            body: SafeArea(
              child: WaterMarkBgView(
                text: '',
                path: logic.background.value,
                backgroundColor: Styles.c_FFFFFF,
                newMessageCount:
                    logic.isSingleChat ? logic.unreadCount.value : 0,
                onSeeNewMessage: logic.onSeeNewMessage,
                floatView: _groupCallHintView,
                topView: _buildTopView(),
                bottomView: logic.isMultiSelectMode.value
                    ? Container(
                        color: Styles.c_F0F2F6,
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              child: GestureDetector(
                                onTap: () => logic.batchDelMessages(),
                                child: Column(
                                  children: [
                                    ImageRes.multiBoxDel.toImage..width = 40.w,
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      StrRes.menuDel,
                                      style: TextStyle(color: Styles.c_FF381F),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              child: GestureDetector(
                                onTap: () => logic.setMergeMessage(),
                                child: Column(
                                  children: [
                                    ImageRes.multiBoxForward.toImage
                                      ..width = 40.w,
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(StrRes.mergeForward)
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    : NotificationListener<SizeChangedLayoutNotification>(
                        onNotification: (notification) {
                          logic.scrollBottom();
                          return true;
                        },
                        child: SizeChangedLayoutNotifier(
                          child: Obx(() {
                            // 依赖 logic.enabled / isGroupMute（内部读 _groupMuted、isMute），禁言状态变化时输入框会立即刷新
                            final enabled = logic.enabled;
                            final isGroupMute = logic.isGroupMute;
                            return ChatInputBox(
                              key: logic.chatInputKey,
                              forceCloseToolboxSub: logic.forceCloseToolbox,
                              toolboxController: logic.toolboxController,
                              controller: logic.inputCtrl,
                              focusNode: logic.focusNode,
                              enabledAt: logic.isGroupChat,
                              enabled: enabled,
                              hintText: enabled
                                  ? ""
                                  : isGroupMute
                                      ? "已开启群禁言"
                                      : "你已被禁言",
                              isNotInGroup: logic.isInvalidGroup,
                              atUserInfo: logic.curMsgAtUserInfos,
                              directionalText: logic.directionalText(),
                              onCloseDirectional: logic.onClearDirectional,
                              onSend: logic.sendTextMsg,
                              onClearQuote: () => logic.quote.value = null,
                              quoteContent: quoteContent,
                              toolbox: ChatToolBox(
                                onTapAlbum: logic.onTapAlbum,
                                onTapCall: logic.isGroupChat ? null : logic.call,
                                onTapTransfer: (!logic.isGroupChat &&
                                        logic.orgController.currentOrgRoles
                                            .contains("transfer"))
                                    ? _startTransfer
                                    : null,
                                onTapRedEnvelope: logic
                                        .orgController.currentOrgRoles
                                        .contains("send_red_packet")
                                    ? () => logic.onTapLuckMoney(context)
                                    : null,
                                onTapEmoji: () => logic.onTapEmoji(context),
                                onTapFile: logic.orgController.currentOrgRoles
                                        .contains("basic")
                                    ? () => logic.onTapFile(context)
                                    : null,
                                onTapCarte: (!logic.isGroupChat &&
                                    logic.orgController.currentOrgRoles
                                        .contains("basic"))
                                    ? () => logic.onTapCarte()
                                    : null,
                              ),
                              voiceRecordBar: VoiceRecordBar(
                                onSondVoice: (int duration, String path) =>
                                    logic.onSondVoice(duration, path),
                                quoteContent: quoteContent,
                              ),
                            );
                          }),
                        ),
                      ),
                                  child: TouchCloseSoftKeyboard(
                    child: Opacity(
                  opacity: logic.isReadyToShow.value ? 1.0 : 0.0,
                  child: Obx(() {
                    final listEmpty = logic.customChatListViewController.list.isEmpty;
                    final showEmptyHint = logic.firstLoadEmpty.value && listEmpty && logic.searchMessage == null;
                    return Stack(
                      children: [
                        CustomChatListView(
                          controller: logic.customChatListViewController,
                          key: const ValueKey('chat_list_stable'),
                          scrollController: logic.scrollController,
                          enabledBottomLoad: logic.searchMessage != null &&
                              logic.enabledBottomLoad.value,
                          enabledTopLoad: logic.enabledTopLoad.value,
                          onScrollToBottomLoad: logic.onScrollToBottomLoad,
                          onScrollToTopLoad: logic.onScrollToTopLoad,
                          itemBuilder: (context, index, postion, message) {
                            if (_isNotificationMessage(message)) {
                              return AutoScrollTag(
                                key: ValueKey('notification_${message.clientMsgID}'),
                                controller: logic.scrollController,
                                index: postion,
                                child: _buildNotificationMessage(message),
                              );
                            }
                            return AutoScrollTag(
                                key: ValueKey('message_${message.clientMsgID}'),
                                controller: logic.scrollController,
                                index: postion,
                                child: Obx(() => _buildItemView(message)));
                          },
                        ),
                        if (showEmptyHint)
                          Positioned.fill(
                            child: Container(
                              color: Styles.c_FFFFFF,
                              alignment: Alignment.center,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24.w),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('暂无消息', style: Styles.ts_8E9AB0_15sp),
                                    SizedBox(height: 8.h),
                                    Text('请返回会话列表下拉刷新后重试', style: Styles.ts_8E9AB0_13sp, textAlign: TextAlign.center),
                                    SizedBox(height: 16.h),
                                    TextButton(
                                      onPressed: () => logic.retryLoadHistory(),
                                      child: Text('重试', style: Styles.ts_0089FF_14sp),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                )),
              ),
            ));
      }),
    );
  }

  Widget? _buildTopView() {
    if (logic.isGroupChat) {
      return Obx(() {
        // 添加对空公告的检查，如果公告内容为空，不显示横幅
        if (logic.isReadNotification.value || logic.notification.value.trim().isEmpty) {
          return const SizedBox();
        } else {
          return GestureDetector(
            onTap: () {
              logic.toNotivication();
            },
            child: Container(
              padding: EdgeInsets.only(top: 8.w, left: 8.w, right: 8.w),
              color: Styles.c_FFFFFF,
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.r),
                  color: Styles.c_0089FF_opacity10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ImageRes.notice.toImage..width = 25.w,
                            Text(
                              StrRes.groupAc,
                              style: Styles.ts_0089FF_17sp,
                            )
                          ],
                        ),
                        ImageRes.closeGroupNotice.toImage
                          ..width = 16.w
                          ..onTap = () {
                            logic.setAcReadTime();
                          }
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      logic.notification.value,
                      style: Styles.ts_0C1C33_17sp,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    )
                  ],
                ),
              ),
            ),
          );
        }
      });
    }
    return null;
  }

  // 判断是否为通知消息
  bool _isNotificationMessage(Message message) {
    if (message.contentType != MessageType.custom) return false;

    try {
      final data = IMUtils.parseCustomMessage(message);
      return data != null && data['viewType'] == CustomMessageType.recover;
    } catch (e) {
      return false;
    }
  }

  // 构建通知消息视图
  Widget _buildNotificationMessage(Message message) {
    String content = '';

    try {
      final data = IMUtils.parseCustomMessage(message);
      if (data != null) {
        content = data['content'] ?? '';
      }
    } catch (e) {
      ILogger.d('解析通知消息出错: $e');
    }

    // 如果内容为空,不显示
    if (content.isEmpty) return SizedBox();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 5.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Center(
        child: Text(
          content,
          style: TextStyle(
            color: Color(0xFF8E9AB0),
            fontSize: 12.sp,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
