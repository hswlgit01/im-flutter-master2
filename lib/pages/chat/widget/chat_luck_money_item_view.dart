import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/core/wallet_controller.dart';
import 'package:openim/pages/luck_money/luck_money_logic.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/utils/error_handler.dart';
import 'package:sprintf/sprintf.dart';
import '../../../core/api_service.dart' as core;
import '../../../utils/luck_money_status_manager.dart';
import '../../conversation/conversation_logic.dart';

import '../chat_logic.dart';

enum LuckMoneyScene {
  Friend('FRIEND'), // 私聊  FRIEND
  Group('GROUP'); // 群聊  GROUP

  final String value;
  const LuckMoneyScene(this.value);
}

enum LuckyMoneyCode {
  // 红包code
  LuckyMoneyFriendNormal('IM_CHART_LUCKYMONEY_FRIEND_NORMAL'),
  LuckyMoneyGroupNormal('IM_CHART_LUCKYMONEY_GROUP_NORMAL'),
  LuckyMoneyGroupSpecial('IM_CHART_LUCKYMONEY_GROUP_SPECIAL'),
  LuckyMoneyGroupRandom('IM_CHART_LUCKYMONEY_GROUP_RANDOM');

  final String value;
  const LuckyMoneyCode(this.value);
}

class ChatLuckMoneyItemView extends StatefulWidget {
  final Map<String, dynamic> data;

  const ChatLuckMoneyItemView({
    super.key,
    required this.data,
  });

  @override
  State<ChatLuckMoneyItemView> createState() => _ChatLuckMoneyItemViewState();
}

class _ChatLuckMoneyItemViewState extends State<ChatLuckMoneyItemView>
    with AutomaticKeepAliveClientMixin {
  /// 可能存在于聊天页面上下文中，也可能在其他页面（如预览）中单独渲染，此时不存在 ChatLogic
  ChatLogic? chartLogic;

  late String currentStatus;
  bool isLoading = false;
  final String _uniqueId = UniqueKey().toString();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 尝试获取 ChatLogic；如果当前不在聊天页面上下文中（例如某些预览页），则降级为 null
    try {
      chartLogic = Get.find<ChatLogic>(tag: GetTags.chat);
    } catch (_) {
      chartLogic = null;
    }

    // 首先从消息中获取初始状态
    final status = widget.data['status'] as String? ?? 'pending';
    currentStatus = status;

    // 然后尝试从本地存储中获取更新的状态
    _loadStatusFromLocalStorage();
  }

  // 从本地存储中加载状态（重启进入会话后若 logic 的 map 尚未写入，这里读到已领取会同步到 map 以驱动 Obx）
  Future<void> _loadStatusFromLocalStorage() async {
    try {
      final transactionId = widget.data['msg_id'] as String?;
      if (transactionId == null || transactionId.isEmpty) return;

      // 只读取“我是否已领取”的状态：仅当本机点击过并写入 completed 时才更新，
      // 未点击过的人始终保持待领取。
      final storedStatus = await LuckMoneyStatusManager.getLuckMoneyStatus(
        transactionId,
        userId: OpenIM.iMManager.userID,
      );

      if (storedStatus == 'completed') {
        // 当前用户已领取：同步到 ChatLogic 的响应式 map，确保 Obx 立即显示「已领取」灰色
        chartLogic?.redPacketStatusMap[transactionId] = 'completed';
        chartLogic?.redPacketStatusMap.refresh();
        if (mounted) {
          setState(() {
            currentStatus = 'completed';
            widget.data['status'] = 'completed';
            widget.data['isReceived'] = true;
          });
        }
        return;
      }
    } catch (e) {
      Logger.print('从本地存储加载红包状态失败: $e');
    }
  }

  // 检查群组红包的领取状态（纯查询，不直接改气泡/UI，由调用方根据结果决定后续行为）
  Future<Map<String, bool>> _checkGroupLuckMoneyStatus() async {
    try {
      final transactionId = widget.data['msg_id'];
      if (transactionId == null) {
        return {'completed': false, 'received': false};
      }

      final apiService = core.ApiService();
      final result = await apiService.transactionCheckCompleted(
        transaction_id: transactionId,
      );

      // 后端返回结构为 { errCode, errMsg, data: { completed, received } }
      final Map<String, dynamic>? data =
          result is Map<String, dynamic> ? result['data'] as Map<String, dynamic>? : null;
      if (data != null) {
        final bool isCompleted = data['completed'] == true;
        final bool hasReceived = data['received'] == true;
        return {'completed': isCompleted, 'received': hasReceived};
      }
    } catch (e) {
      Logger.print('检查群组红包状态失败: $e');
    }

    return {'completed': false, 'received': false};
  }

  @override
  void didUpdateWidget(ChatLuckMoneyItemView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检查数据中的状态是否更新
    if (oldWidget.data['status'] != widget.data['status']) {
      setState(() {
        currentStatus = widget.data['status'];
      });
    }

    // 无论如何都重新检查本地存储，确保状态始终最新
    _loadStatusFromLocalStorage();
  }

  /// 优先使用 ChatLogic 中从本地恢复的红包状态（重启进入会话后已写入），再回退到 currentStatus
  String get effectiveStatus =>
      chartLogic?.redPacketStatusMap[widget.data['msg_id'] as String?] ??
      currentStatus;

  String statusTextFrom(String status) {
    if (isExpired) return StrRes.expired;
    switch (status.toLowerCase()) {
      case 'pending':
        return StrRes.toBeClaimed;
      case 'completed':
        return StrRes.claimed;
      case 'refunded':
        return StrRes.refunded;
      case 'expired':
        return StrRes.expired;
      default:
        return status;
    }
  }

  /// 气泡展示文案：
  /// - 未点击或点击失败前：status=pending → “待领取”
  /// - 只要本机点击过并被标记为 completed → “已领取”（不再区分是否真的抢到金额）
  /// - 红包过期：统一显示“已过期”
  String get statusText {
    final status = effectiveStatus;
    if (isExpired) return StrRes.expired;
    return statusTextFrom(status);
  }

  List<Color> statusColorFrom(String status) {
    if (isExpired) {
      return [
        Color(0xFFF5A623).withOpacity(0.6),
        Colors.red.shade300.withOpacity(0.6)
      ];
    }
    switch (status.toLowerCase()) {
      case 'pending':
        return [Color(0xFFF5A623), Colors.red.shade600];
      case 'completed':
      case 'refunded':
      case 'expired':
        return [
          Color(0xFFF5A623).withOpacity(0.6),
          Colors.red.shade300.withOpacity(0.6)
        ];
      default:
        return [Colors.grey.shade300, Colors.grey.shade400];
    }
  }

  List<Color> get statusColor => statusColorFrom(effectiveStatus);

  bool get self => widget.data['sender'] == OpenIM.iMManager.userID;
  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > widget.data['expire_time'];
  bool get isFriend => widget.data['extension']['scene'] == 'FRIEND';

  Future<void> _handleReceiveSuccess(Map<String, dynamic> result) async {
    try {
      Logger.print('处理红包领取成功...');

      // 提取关键数据
      final receivedAmount = result['data']?['amount'] ?? '0.00';
      final sender = widget.data['sender_nickname'] ?? '未知用户';

      // 更新红包状态（必须 await 以保证本地已领取状态持久化，避免退出 App 后丢失）
      await _updateLocalRedPacketStatus(receivedAmount);

      // 发送相应的通知消息
      await _sendRedPacketNotification(sender);

      // 显示成功提示并跳转到详情页
      _showSuccessTipAndNavigateToDetail();
    } catch (e) {
      Logger.print('处理红包领取成功时出错: $e');
      Get.snackbar('提示', '红包领取成功,但处理过程中出现错误',
          backgroundColor: Colors.amber, colorText: Colors.black);
    }
  }

  // 更新红包本地状态（必须 await 保存完成，否则退出 App 后重启会丢失「已领取」状态）
  Future<void> _updateLocalRedPacketStatus(String receivedAmount) async {
    if (!mounted) return;

    setState(() {
      currentStatus = 'completed';
      widget.data['isReceived'] = true;
      widget.data['status'] = 'completed';
      widget.data['received_amount'] = receivedAmount;

      // 更新领取计数
      int receivedCount = widget.data['received_count'] ?? 0;
      widget.data['received_count'] = receivedCount + 1;

      // 添加领取记录
      final now = DateTime.now().millisecondsSinceEpoch;
      final receiverInfo = {
        'user_id': OpenIM.iMManager.userID,
        'nickname': OpenIM.iMManager.userInfo.nickname,
        'face_url': OpenIM.iMManager.userInfo.faceURL,
        'amount': receivedAmount,
        'received_time': now
      };

      // 创建或更新红包接收记录列表，仅保留最近 50 条避免消息体过大（大群推送易触发 websocket close 1009）
      const int kMaxReceiversInBubble = 50;
      List<dynamic> receivers = List<dynamic>.from(widget.data['receivers'] ?? []);
      receivers.add(receiverInfo);
      if (receivers.length > kMaxReceiversInBubble) {
        receivers = receivers.sublist(receivers.length - kMaxReceiversInBubble);
      }
      widget.data['receivers'] = receivers;
    });

    final transactionId = widget.data['msg_id'];
    if (transactionId != null) {
      // 必须先 await 持久化，否则用户马上退出 App 时可能尚未写入，重启后仍显示待领取
      await LuckMoneyStatusManager.saveLuckMoneyStatus(transactionId, 'completed', userId: OpenIM.iMManager.userID);
      // 同步到会话内缓存，Obx 会立即刷新为已领取
      chartLogic?.redPacketStatusMap[transactionId] = 'completed';
      chartLogic?.redPacketStatusMap.refresh();
      // 刷新会话列表摘要，使聊天列表显示 [已领取] 而非 [待领取]
      try {
        await Get.find<ConversationLogic>().loadRedPacketStatusCache();
      } catch (_) {}
      await LuckMoneyStatusManager.saveDetailSnapshot(transactionId, {
        'self_amount': receivedAmount,
        'self_received': true,
        'status': 'completed',
        'received_count': widget.data['received_count'],
        'total_count': widget.data['total_count'],
        'received_amount': widget.data['received_amount']?.toString(),
        'total_amount': widget.data['total_amount']?.toString(),
      }, userId: OpenIM.iMManager.userID);
    }
  }

  // 发送红包领取通知
  Future<void> _sendRedPacketNotification(String sender) async {
    try {
      final chatLogic = Get.find<ChatLogic>(tag: GetTags.chat);
      final isGroupLuckMoney = chatLogic.isGroupChat;

      if (!isGroupLuckMoney) {
        // 单聊红包处理: 发送状态更新消息，仅带必要字段与最近 N 条领取记录，避免消息体过大
        const int kMaxReceiversInSyncMsg = 20;
        final Map<String, dynamic> dataToSend = Map<String, dynamic>.from(widget.data);
        if (dataToSend['receivers'] is List && (dataToSend['receivers'] as List).length > kMaxReceiversInSyncMsg) {
          final List<dynamic> list = List<dynamic>.from(dataToSend['receivers'] as List);
          dataToSend['receivers'] = list.sublist(list.length - kMaxReceiversInSyncMsg);
        }
        final messageData = {
          "customType": CustomMessageType.luckMoney,
          "data": dataToSend,
          "viewType": CustomMessageType.luckMoney
        };

        chatLogic.sendCustomMsg(
            data: jsonEncode(messageData), extension: '', description: '红包');
      } else {
         // 群聊红包处理: 不再发送群广播消息，改由后端定向通知
        // 之前的逻辑是发送一条 CustomMessageType.recover 消息，会导致全员广播
        Logger.print('群红包领取成功，不再发送群广播消息');

        /* 移除旧的广播逻辑
        final nickname = OpenIM.iMManager.userInfo.nickname ?? '我';

        // 构建通知内容
        final notificationContent = sprintf(StrRes.rPBMsg, [nickname, sender]);

        final messageData = {
          "customType": CustomMessageType.recover,
          'content': notificationContent,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          "viewType": CustomMessageType.recover
        };
        chatLogic.sendCustomMsg(
            data: jsonEncode(messageData), extension: '', description: '系统通知');
        */
        // // 创建通知消息
        // final message =
        //     await OpenIM.iMManager.messageManager.createCustomMessage(
        //         data: jsonEncode({
        //           'customType': CustomMessageType.recover,
        //           'content': notificationContent,
        //           'timestamp': DateTime.now().millisecondsSinceEpoch,
        //           'viewType': CustomMessageType.recover
        //         }),
        //         extension: '',
        //         description: '系统通知');

        // // 发送消息到群组
        // final roomId = widget.data['roomid'];
        // if (roomId != null && roomId.isNotEmpty) {
        //   await OpenIM.iMManager.messageManager.sendMessage(
        //       message: message,
        //       groupID: roomId,
        //       offlinePushInfo: OfflinePushInfo(
        //           title: '系统通知',
        //           desc: notificationContent,
        //           iOSBadgeCount: false));

        //   Logger.print('红包领取通知已发送');
        // } else {
        //   Logger.print('发送通知失败:群组ID为空');
        // }
      }

      // 刷新消息列表
      chatLogic.customChatListViewController.refresh();
    } catch (e) {
      Logger.print('发送红包通知消息失败: $e');
      // 即使通知发送失败,也不影响红包领取流程
    }
  }

  // 显示成功提示并跳转到详情页
  void _showSuccessTipAndNavigateToDetail() {
    // 立即跳转到详情页
    final msgId = widget.data['msg_id'] ?? '';
    AppNavigator.startLuckMoneyDetail(
      msgId: msgId,
      data: widget.data,
    );

    // 显示成功提示
    Get.snackbar(
      StrRes.claimSuccessful,
      StrRes.transferredToWallet,
      backgroundColor: const Color(0xFF07C160),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.only(bottom: 20.h, left: 20.w, right: 20.w),
    );
  }

  onTapLuckMoney([String? password]) {
    final walletController = Get.find<WalletController>();
    walletController.checkWalletetActivated(() async {
      if (isLoading) return;

      // 输出输入的口令（如果有的话）
      if (password != null) {
        Logger.print('用户输入的口令: $password');
      }

      setState(() {
        isLoading = true;
      });

      try {
        Logger.print('开始处理红包领取...');
        final transactionId = widget.data['msg_id'];

        if (transactionId == null || transactionId.isEmpty) {
          throw Exception('无效的红包ID');
        }

        // 调用领取红包接口
        final apiService = core.ApiService();
        // 红包和转账共用同一个接口
        final result = await LoadingView.singleton.wrap(
            asyncFunction: () => apiService.transactionReceive(
                transaction_id: transactionId, password: password));

        if (result['success'] == true) {
          await _handleReceiveSuccess(result);
        } else {
          // ValidateReceiverInfo 相关错误码处理
          int errorCode = result['code'] ?? 0;

          // 处理接收者验证相关错误码
          if (errorCode == 10114) {
            IMViews.showToast(StrRes.receiverNotInOrganization);
          } else if (errorCode == 10115) {
            IMViews.showToast(StrRes.userNotInSameOrganization);
          } else if (errorCode == 10116) {
            IMViews.showToast(StrRes.cannotReceiveOwnTransfer);
          } else if (errorCode == 10117) {
            IMViews.showToast(StrRes.receiverNotTargetUser);
          } else if (errorCode == 10118) {
            IMViews.showToast(StrRes.orgTransferReceiverMustBeAdmin);
          } else if (errorCode == 10119) {
            IMViews.showToast(StrRes.receiverNotExclusiveReceiver);
          } else if (errorCode == 10120) {
            IMViews.showToast(StrRes.unknownTransactionType);
          } else if (errorCode == 10121) {
            IMViews.showToast(StrRes.incorrectPassword);
          } else if (errorCode == 10122) {
            IMViews.showToast(StrRes.passwordCannotBeEmpty);
          }
          // 处理红包状态相关错误码
          else if (result['code'] == 10109 ||
              result['code'] == 10102) {
            // 10109: 红包已领完, 10102: 红包已过期/不存在
            if (result['code'] == 10102) {
              // 过期场景：气泡统一显示“已过期”
              setState(() {
                currentStatus = 'expired';
                widget.data['status'] = 'expired';
                widget.data['isReceived'] = false;
                isLoading = false;
              });
            } else {
              // 10109 已领完：只要本机点开过，就按“已领取”展示
              setState(() {
                currentStatus = 'completed';
                widget.data['status'] = 'completed';
                widget.data['isReceived'] = true;
                isLoading = false;
              });
              if (transactionId != null) {
                await LuckMoneyStatusManager.saveLuckMoneyStatus(
                    transactionId, 'completed',
                    userId: OpenIM.iMManager.userID);
                try {
                  final chatLogic = Get.find<ChatLogic>(tag: GetTags.chat);
                  chatLogic.redPacketStatusMap[transactionId] = 'completed';
                  chatLogic.redPacketStatusMap.refresh();
                } catch (_) {}
              }
            }

            // 获取错误信息
            String errorMessage = '';
            if (result['code'] == 10109) {
              errorMessage = StrRes.redPacketFull;
            } else if (result['code'] == 10102) {
              errorMessage = StrRes.redPacketExpired;
            } else {
              errorMessage = result['message'] ?? StrRes.claimFailed;
            }
            // 显示错误提示对话框，并提供查看详情按钮
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (context) => LuckMoneyDialog(
                  onTapLuckMoney: (String? password) {},
                  data: widget.data,
                  errorMessage: errorMessage,
                ),
              );
            }
          }
          // 【优化】10104 已领取过：使用更准确的文案，不再显示"红包无效"
          else if (result['code'] == 10104) {
            // 用户已领取过该红包，跳转到详情页查看
            setState(() {
              currentStatus = 'completed';
              widget.data['status'] = 'completed';
              widget.data['isReceived'] = true;
              if (transactionId != null) {
                LuckMoneyStatusManager.saveLuckMoneyStatus(
                    transactionId, 'completed', userId: OpenIM.iMManager.userID);
              }
              isLoading = false;
            });
            // 使用更准确的提示文案
            IMViews.showToast(StrRes.alreadyReceived);
            // 直接跳转到详情页
            final msgId = widget.data['msg_id'] ?? '';
            AppNavigator.startLuckMoneyDetail(
              msgId: msgId,
              data: widget.data,
            );
          } else {
            // 优化错误提示：高并发场景下的友好提示
            int errorCode = result['code'] ?? 0;
            String? errorMessage = result['message']?.toString() ?? result['errMsg']?.toString();

            // 10000 系统错误：若消息包含「请稍后重试」或「红包状态异常」，显示友好提示
            if (errorCode == 10000 && errorMessage != null &&
                (errorMessage.contains('请稍后重试') || errorMessage.contains('红包状态异常'))) {
              IMViews.showToast(StrRes.redPacketRetry);
            }
            // 10130 操作过于频繁：显示友好提示
            else if (errorCode == 10130) {
              IMViews.showToast(StrRes.redPacketRetry);
            }
            // 10131 交易无效：显示红包已过期
            else if (errorCode == 10131) {
              IMViews.showToast(StrRes.redPacketExpired);
            }
            // 其他错误：使用标准错误处理
            else {
              ErrorHandler().handleBusinessError(errorCode, customMessage: errorMessage);
            }
          }
        }
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      } catch (e) {
        Logger.print('红包领取过程中发生错误: $e');

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        // Get.snackbar(
        //   StrRes.claimFailed,
        //   '${e.toString().replaceAll('Exception: ', '')}',
        //   backgroundColor: Colors.red,
        //   colorText: Colors.white,
        //   snackPosition: SnackPosition.BOTTOM,
        //   margin: EdgeInsets.only(bottom: 20.h, left: 20.w, right: 20.w),
        // );
      }
    });
  }

  _send(BuildContext context) async {
    // 检查红包是否已领完
    final int receivedCount = widget.data['received_count'] ?? 0;
    final int totalCount = widget.data['total_count'] ?? 1;
    final bool isFullyReceived = receivedCount >= totalCount;

    // 检查当前用户是否已领取过这个红包
    final bool userHasReceived = widget.data['isReceived'] == true ||
        currentStatus.toLowerCase() == 'completed';

    // 如果是群组红包，先检查状态
    final isGroupLuckMoney = widget.data['extension']?['lucky_money_scene'] ==
        LuckMoneyScene.Group.value;

    // 检查是否是自己发出的红包
    final isSelfLuckMoney = widget.data['sender'] == OpenIM.iMManager.userID;

    // 检查专属红包但当前用户不是指定接收者
    // final isSpecialLuckMoneyAndReceiver = widget.data['extension']?['lucky_money_type'] ==
    //     LuckyMoneyType.Special.value && widget.data['extension']?['special_receiver_id'] !=
    //       OpenIM.iMManager.userID;

    if (isGroupLuckMoney) {
      final status = await LoadingView.singleton
          .wrap(asyncFunction: () => _checkGroupLuckMoneyStatus());

      if (status['received'] == true || status['completed'] == true) {
        // 群红包：当前用户点击过一个“已结束/已领取”的红包，按需求统一视为“已领取”
        setState(() {
          currentStatus = 'completed';
          widget.data['status'] = 'completed';
          widget.data['isReceived'] = true;
        });
        final transactionId = widget.data['msg_id'];
        if (transactionId != null) {
          await LuckMoneyStatusManager.saveLuckMoneyStatus(
              transactionId, 'completed',
              userId: OpenIM.iMManager.userID);
          try {
            chartLogic?.redPacketStatusMap[transactionId] = 'completed';
            chartLogic?.redPacketStatusMap.refresh();
          } catch (_) {}
        }

        final msgId = widget.data['msg_id'] ?? '';
        AppNavigator.startLuckMoneyDetail(
          msgId: msgId,
          data: widget.data,
        );
        return;
      }
    }

    // 检查是否符合查看详情的条件
    // 1. 自己发出的红包可以查看详情
    // 2. 已经领取过的红包可以查看详情
    // 3. 其他情况不能查看详情
    bool canViewDetails = isSelfLuckMoney || userHasReceived;

    // 已领完、已过期或已退还的红包，且不是自己发的红包、也没有领取过的红包，不允许查看详情
    bool cannotViewDetails = (isFullyReceived ||
                             isExpired ||
                             widget.data['status'] == 'refunded') &&
                             !canViewDetails;

    if (cannotViewDetails) {
      // 不能查看详情，也不能领取，直接返回
      return;
    }

    // 如果可以查看详情但不能领取
    bool canOnlyViewDetails = isExpired ||
        isFullyReceived ||
        widget.data['status'] == 'refunded' ||
        userHasReceived ||
        (!isGroupLuckMoney && isSelfLuckMoney);

    if (canOnlyViewDetails) {
      // 只能查看详情，不能领取
      final msgId = widget.data['msg_id'] ?? '';
      AppNavigator.startLuckMoneyDetail(
        msgId: msgId,
        data: widget.data,
      );
      return;
    }

    final user = await LoadingView.singleton.wrap(asyncFunction: () async {
      if (OpenIM.iMManager.userInfo.userID == widget.data['sender']) {
        return OpenIM.iMManager.userInfo;
      }
      return (await OpenIM.iMManager.friendshipManager
              .getFriendsInfo(userIDList: [widget.data['sender']]))
          .firstOrNull;
    });

    // 可以领取红包
    showGeneralDialog(
      context: context,
      barrierLabel: "Dialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => LuckMoneyDialog(
          senderInfo: user,
          onTapLuckMoney: (String? password) => onTapLuckMoney(password),
          data: widget.data),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    String luckyMoneyType = widget.data['extension']?['lucky_money_type'] ??
        LuckyMoneyType.Normal.value;
    String title = luckyMoneyType != LuckyMoneyType.Special.value
        ? (widget.data['remark']?.toString().isNotEmpty == true
            ? widget.data['remark']
            : StrRes.redPacketHitStr)
        : sprintf(StrRes.redPacketForRecipient,
            [widget.data['extension']?['special_receiver_name']]);

    // 如果存在 ChatLogic，则用 Obx 订阅其红包状态映射；否则退化为仅使用本地 currentStatus 渲染
    if (chartLogic != null) {
      return Obx(() {
        final _ =
            chartLogic!.redPacketStatusMap[widget.data['msg_id'] as String?];
        final colors = statusColorFrom(effectiveStatus);
        final text = statusTextFrom(effectiveStatus);
        return GestureDetector(
          onTap: () => _send(context),
          child: Container(
            width: 200.w,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white,
                      size: 16.w,
                    ),
                    8.horizontalSpace,
                    Expanded(
                        child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                  ],
                ),
                10.verticalSpace,
                Container(
                  margin: EdgeInsets.only(top: 4.h),
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });
    }

    // 无 ChatLogic 场景：直接使用 currentStatus 渲染，不绑定全局状态
    final colors = statusColorFrom(currentStatus);
    final text = statusTextFrom(currentStatus);
    return GestureDetector(
      onTap: () => _send(context),
      child: Container(
        width: 200.w,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 16.w,
                ),
                8.horizontalSpace,
                Expanded(
                    child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                )),
              ],
            ),
            10.verticalSpace,
            Container(
              margin: EdgeInsets.only(top: 4.h),
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LuckMoneyDialog extends StatefulWidget {
  final Function(String?) onTapLuckMoney; // 修改为接受可选的密码参数
  final Map<String, dynamic> data;
  final dynamic senderInfo;
  final String? errorMessage; // 添加错误信息参数

  const LuckMoneyDialog({
    super.key,
    required this.onTapLuckMoney,
    required this.data,
    this.errorMessage, // 可选的错误信息
    this.senderInfo,
  });

  @override
  State<LuckMoneyDialog> createState() => _LuckMoneyDialogState();
}

class _LuckMoneyDialogState extends State<LuckMoneyDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _hasInputValue = false;

  @override
  void initState() {
    super.initState();
    // 只有在密码红包时才监听输入框变化
    if (isPasswordRedPacket) {
      _passwordController.addListener(() {
        setState(() {
          _hasInputValue = _passwordController.text.trim().isNotEmpty;
        });
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // 判断是否是密码红包
  bool get isPasswordRedPacket {
    return widget.data['extension']?['lucky_money_type'] ==
        LuckyMoneyType.Password.value;
  }

  bool get isRedPacketClaimable {
    if (widget.data['extension']?['lucky_money_type'] ==
        LuckyMoneyType.Special.value) {
      if (widget.data['extension']?['special_receiver_id'] !=
          OpenIM.iMManager.userID) {
        return false;
      }
    }
    return true;
  }

  // 判断是否应该显示"查看详情"按钮
  bool _shouldShowViewDetailsButton() {
    // 如果是错误信息对话框，并且错误是由于专属红包引起的，显示详情按钮
    if (!isRedPacketClaimable) {
      return true;
    }

    // 如果有错误信息，需要进一步判断
    if (widget.errorMessage != null) {
      // 检查是否是自己发的红包
      bool isSelfLuckMoney = widget.data['sender'] == OpenIM.iMManager.userID;

      // 检查是否已经领取过这个红包
      bool userHasReceived = widget.data['isReceived'] == true;

      // 如果满足条件则显示详情按钮
      return isSelfLuckMoney || userHasReceived;
    }

    return false;
  }

  String get title {
    if (widget.errorMessage != null) {
      return widget.errorMessage!;
    }
    if (isRedPacketClaimable) {
      if (widget.data['remark']?.toString().isNotEmpty == true) {
        return widget.data['remark'];
      } else {
        return StrRes.redPacketHitStr;
      }
    }
    return sprintf(StrRes.onlyRecipientCanClaim,
        [widget.data['extension']?['special_receiver_name']]);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 2 / 3,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 79, 66),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.senderInfo != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarView(
                              width: 24.w,
                              height: 24.w,
                              url: widget.senderInfo!.faceURL,
                              text: widget.senderInfo!.nickname,
                            ),
                            4.horizontalSpace,
                            Text(
                              sprintf(StrRes.redPacketSentByUser,
                                  [widget.senderInfo!.nickname]),
                              style: TextStyle(
                                color: Colors.amber[300],
                              ),
                            ),
                          ],
                        ),
                      10.verticalSpace,
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.amber[300],
                        ),
                      ),
                      const SizedBox(height: 100),
                      // 只有密码红包才显示口令输入框
                      if (isPasswordRedPacket)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom: 40.h, left: 60.w, right: 60.w),
                          child: TextField(
                            controller: _passwordController,
                            textAlign: TextAlign.center,
                            cursorColor: Colors.white70,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: StrRes.enterPasswordPrompt,
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.white70, width: 0.5.h),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.white70, width: 0.5.h),
                              ),
                              hintStyle: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14.sp),
                            ),
                          ),
                        ),
                      if (widget.errorMessage != null || !isRedPacketClaimable)
                        const SizedBox(
                          height: 80,
                        ),
                      // 只在没有错误时显示开按钮
                      if (widget.errorMessage == null && isRedPacketClaimable)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700], // 金色背景
                            minimumSize: Size(80, 80), // 圆形按钮大小
                            shape: CircleBorder(), // 圆形
                            elevation: 4, // 阴影
                          ), // 只有密码红包才需要验证输入框，其他类型红包直接可点击
                          onPressed: (isPasswordRedPacket && !_hasInputValue)
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  // 如果是密码红包，传递输入的口令；否则传递null
                                  final password = isPasswordRedPacket
                                      ? _passwordController.text.trim()
                                      : null;
                                  widget.onTapLuckMoney(password);
                                },
                          child: Text(
                            StrRes.open,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 在底部添加查看详情按钮，在特定条件下显示
              if (_shouldShowViewDetailsButton())
                Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      final msgId = widget.data['msg_id'] ?? '';
                      AppNavigator.startLuckMoneyDetail(
                        msgId: msgId,
                        data: widget.data,
                        isErrorRedirect: widget.errorMessage != null,
                      );
                    },
                    child: Text(
                      StrRes.viewDetails,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber[200],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ]),
      ),
    );
  }
}
