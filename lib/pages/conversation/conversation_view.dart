import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/core/controller/im_controller.dart';
import 'package:openim_common/openim_common.dart';
import 'package:sprintf/sprintf.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'conversation_logic.dart';

class ConversationPage extends StatelessWidget {
  final VoidCallback openParentDrawer;
  final appName = ''.obs;
  final logic = Get.find<ConversationLogic>();
  final im = Get.find<IMController>();

  ConversationPage({super.key, required this.openParentDrawer}) {
    _loadAppInfo();
  }

  /// 处理会话头像URL并返回
  String? _logConversationAvatar(ConversationInfo info) {
    final contentType = info.latestMsg?.contentType ?? -1;
    final sendID = info.latestMsg?.sendID;

    if (contentType == 1400) {
      // OA通知类型
      try {
        final controller = Get.find<NotificationAccountController>();
        // 触发异步获取和更新
        controller.getNotificationAccount(sendID);
      } catch (e) {
        // 忽略异常
      }
    }

    return info.faceURL;
  }

  void _loadAppInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appName.value = packageInfo.appName;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          // dawn 2026-06-22 修复会话页灰色半屏：页面恢复或横屏瞬态时使用白底兜住列表区域。
          backgroundColor: Styles.c_FFFFFF,
          drawerEnableOpenDragGesture: false,
          appBar: TitleBar.conversation(
              statusStr: logic.imSdkStatus,
              isFailed: logic.isFailedSdkStatus,
              popCtrl: logic.popCtrl,
              onAddFriend: logic.addFriend,
              onAddGroup: logic.addGroup,
              // dawn 2026-05-15 修复团队长首页加号功能不展示：任一快捷权限可显示加号菜单。
              hasBaseRule: logic.orgController.canAddFriend ||
                  logic.orgController.canCreateGroup,
              onCreateGroup: logic.createGroup,
              onScan: logic.scan,
              left: Expanded(
                flex: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    //AvatarView(
                    //  width: 42,
                    //  height: 42,
                    //  text: appName.value,
                    //  onTap: () => openParentDrawer(),
                    //),
                    ImageRes.splashLogo.toImage
                      ..width = 42
                      ..height = 42
                      ..fit = BoxFit.contain,
                    const SizedBox(width: 10),
                    Flexible(
                      child: Obx(() => Text(
                            appName.value.isNotEmpty ? appName.value : '加载中...',
                            style: Styles.ts_0C1C33_17sp_medium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )),
                    ),
                    const SizedBox(width: 10),
                    if (null != logic.imSdkStatus &&
                        (!logic.reInstall || logic.isFailedSdkStatus))
                      Flexible(
                          child: SyncStatusView(
                        isFailed: logic.isFailedSdkStatus,
                        statusStr: logic.imSdkStatus!,
                        onTap:
                            logic.isFailedSdkStatus ? logic.onRetrySync : null,
                      )),
                  ],
                ),
              )),
          body: ColoredBox(
            color: Styles.c_FFFFFF,
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: ListView.builder(
                    itemBuilder: (_, index) => _buildItemView(
                      logic.list.elementAt(index),
                    ),
                    itemCount: logic.list.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildItemView(ConversationInfo info) {
    final unReadCount = logic.getUnreadCount(info);
    final isPinned = info.isPinned ?? false;

    return ConversationSwipeTile(
      key: ValueKey(info.conversationID),
      actions: [
        ConversationSwipeAction(
          backgroundColor: Colors.blue,
          label: isPinned ? StrRes.cancelTop : StrRes.top,
          onTap: () => logic.setPinnedConversation(info, !isPinned),
        ),
        if (unReadCount > 0)
          ConversationSwipeAction(
            backgroundColor: Styles.c_707070,
            label: StrRes.markHasRead,
            onTap: () => logic.setReadConversation(info),
          ),
        ConversationSwipeAction(
          backgroundColor: Colors.red,
          label: StrRes.delete,
          onTap: () => logic.removeConversation(info),
        ),
      ],
      onTap: () => logic.toChat(conversationInfo: info),
      child: Stack(
        children: [
          if (info.isPinned ?? false)
            // dawn 2026-06-21 修复会话置顶角标布局：Positioned 必须直接作为 Stack 子节点，避免部分机型出现灰色占位块。
            Positioned(
              top: 0,
              right: 4,
              child: CustomPaint(
                size: const Size(10, 10),
                painter: TrianglePainter(color: Styles.c_0089FF),
              ),
            ),
          Container(
            height: 68,
            // dawn 2026-06-22 修复安卓横竖屏恢复后列表错位：会话列表核心尺寸使用固定逻辑像素，不依赖 ScreenUtil 缩放。
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Stack(
                  children: [
                    AvatarView(
                      width: 48,
                      height: 48,
                      text: logic.getShowName(info),
                      url: _logConversationAvatar(info),
                      isGroup: logic.isGroupChat(info),
                      textStyle: Styles.ts_FFFFFF_14sp_medium,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: logic.getShowName(info).toText
                              ..style = Styles.ts_0C1C33_17sp
                              ..maxLines = 1
                              ..overflow = TextOverflow.ellipsis,
                          ),
                          // dawn 2026-06-21 新增官方人员标识：管理员/团队长单聊在会话列表昵称后展示认证图标。
                          Obx(() => logic.isOfficialConversation(info)
                              ? const OfficialRoleBadge()
                              : const SizedBox.shrink()),
                          const Spacer(),
                          logic.getTime(info).toText
                            ..style = Styles.ts_8E9AB0_12sp,
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          MatchTextView(
                            text: logic.getContent(info),
                            textStyle: Styles.ts_8E9AB0_14sp,
                            prefixSpan: TextSpan(
                              text: '',
                              children: [
                                info.groupAtType != GroupAtType.atNormal
                                    ? TextSpan(
                                        text: '${logic.getPrefixTag(info)} ',
                                        style: Styles.ts_0089FF_14sp_medium,
                                      )
                                    : unReadCount > 0
                                        ? TextSpan(
                                            text: '[${sprintf(StrRes.nPieces, [
                                                  unReadCount
                                                ])}] ',
                                            style: Styles.ts_0089FF_14sp_medium,
                                          )
                                        : const TextSpan(),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          if (info.recvMsgOpt == 0)
                            UnreadCountView(count: unReadCount),
                          if (info.recvMsgOpt == 2)
                            ImageRes.notDisturb.toImage..width = 12,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      child: const SearchBox(
        enabled: false,
        // dawn 2026-06-22 修复安卓尺寸污染：搜索框在首页使用固定高度和边距，避免旋转后被异常缩放。
        height: 36,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        searchIconWidth: 18,
        searchIconHeight: 18,
      ),
      onTap: () => logic.toSearch(),
    );
  }
}

class OfficialRoleBadge extends StatelessWidget {
  const OfficialRoleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(
        Icons.verified,
        size: 14,
        color: Styles.c_0089FF,
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0); // 顶部中点
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ConversationSwipeAction {
  final Color backgroundColor;
  final String label;
  final VoidCallback onTap;

  const ConversationSwipeAction({
    required this.backgroundColor,
    required this.label,
    required this.onTap,
  });
}

class ConversationSwipeTile extends StatefulWidget {
  const ConversationSwipeTile({
    super.key,
    required this.child,
    required this.actions,
    required this.onTap,
  });

  final Widget child;
  final List<ConversationSwipeAction> actions;
  final VoidCallback onTap;

  @override
  State<ConversationSwipeTile> createState() => _ConversationSwipeTileState();
}

class _ConversationSwipeTileState extends State<ConversationSwipeTile> {
  static const double _height = 68;
  static const double _actionWidth = 64;
  double _offset = 0;
  bool _dragging = false;

  double get _maxOffset => widget.actions.length * _actionWidth;

  double _effectiveMaxOffset(double rowWidth) => math.min(_maxOffset, rowWidth);

  void _setOffset(double offset, [double? maxOffset]) {
    final next = offset.clamp(0.0, maxOffset ?? _maxOffset).toDouble();
    if (next != _offset && mounted) {
      setState(() => _offset = next);
    }
  }

  void _close([double? maxOffset]) => _setOffset(0, maxOffset);

  void _settle(double maxOffset) {
    setState(() => _dragging = false);
    _setOffset(_offset > maxOffset / 3 ? maxOffset : 0, maxOffset);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final constrainedWidth = constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : screenWidth;
        final rowWidth = math.min(constrainedWidth, screenWidth);
        final maxOffset = _effectiveMaxOffset(rowWidth);
        final currentOffset = _offset.clamp(0.0, maxOffset).toDouble();
        final actionAreaWidth = maxOffset;
        final actionWidth = widget.actions.isEmpty
            ? 0.0
            : actionAreaWidth / widget.actions.length;
        return SizedBox(
          width: rowWidth,
          height: _height,
          child: ClipRect(
            // dawn 2026-06-23 修复会话滑动按钮层溢出：固定每行高度并限制隐藏操作区宽度，避免调试版出现 99955 像素溢出。
            child: ColoredBox(
              color: Styles.c_FFFFFF,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  if (widget.actions.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: actionAreaWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.actions
                            .map(
                              (action) => SizedBox(
                                width: actionWidth,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    action.onTap();
                                    _close(maxOffset);
                                  },
                                  child: ColoredBox(
                                    color: action.backgroundColor,
                                    child: Center(
                                      child: Text(
                                        action.label,
                                        style: Styles.ts_FFFFFF_14sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  AnimatedPositioned(
                    top: 0,
                    bottom: 0,
                    left: -currentOffset,
                    width: rowWidth,
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (_) {
                        setState(() => _dragging = true);
                      },
                      onHorizontalDragUpdate: (details) {
                        _setOffset(_offset - details.delta.dx, maxOffset);
                      },
                      onHorizontalDragEnd: (_) => _settle(maxOffset),
                      onHorizontalDragCancel: () => _settle(maxOffset),
                      onTap: () {
                        if (_offset > 0) {
                          _close(maxOffset);
                        } else {
                          widget.onTap();
                        }
                      },
                      child: SizedBox(
                        width: rowWidth,
                        height: _height,
                        child: Material(
                          color: Styles.c_FFFFFF,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
