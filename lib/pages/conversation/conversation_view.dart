import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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

  ConversationPage({super.key, required this.openParentDrawer}){
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
          backgroundColor: Styles.c_F8F9FA,
          drawerEnableOpenDragGesture: false,
          appBar: TitleBar.conversation(
              statusStr: logic.imSdkStatus,
              isFailed: logic.isFailedSdkStatus,
              popCtrl: logic.popCtrl,
              onAddFriend: logic.addFriend,
              onAddGroup: logic.addGroup,
              hasBaseRule:
                  logic.orgController.currentOrgRoles.contains("basic"),
              onCreateGroup: logic.createGroup,
              onScan: logic.scan,
              left: Expanded(
                flex: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    //AvatarView(
                    //  width: 42.w,
                    //  height: 42.h,
                    //  text: appName.value,
                    //  onTap: () => openParentDrawer(),
                    //),
                    ImageRes.splashLogo.toImage
                      ..width = 42.w
                      ..height = 42.h
                      ..fit = BoxFit.contain,
                    10.horizontalSpace,
                    Flexible(
                      child: Obx(() => Text(
                            appName.value.isNotEmpty
                                ? appName.value
                                : '加载中...',
                            style: Styles.ts_0C1C33_17sp_medium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )),
                    ),
                    10.horizontalSpace,
                    if (null != logic.imSdkStatus &&
                        (!logic.reInstall || logic.isFailedSdkStatus))
                      Flexible(
                          child: SyncStatusView(
                        isFailed: logic.isFailedSdkStatus,
                        statusStr: logic.imSdkStatus!,
                        onTap: logic.isFailedSdkStatus ? logic.onRetrySync : null,
                      )),
                  ],
                ),
              )),
          body: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: SlidableAutoCloseBehavior(
                    child: ListView.builder(
                  itemBuilder: (_, index) => _buildItemView(
                    logic.list.elementAt(index),
                  ),
                  itemCount: logic.list.length,
                )),
              ),
            ],
          ),
        ));
  }

  Widget _buildItemView(ConversationInfo info) {
    final unReadCount = logic.getUnreadCount(info);
    final isPinned = info.isPinned ?? false;
    double extentRatio = 0.5;
    List<int> flexs = [3, 3, 3];
    if (unReadCount > 0) {
      extentRatio += 0.3;
      flexs[1]++;
    }
    if (isPinned) {
      extentRatio = min(0.8, 0.15 + extentRatio);
      flexs[0]++;
    }

    return Slidable(
        key: ValueKey(info.conversationID),
        endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: extentRatio,
            children: [
              CustomSlidableAction(
                  backgroundColor: Colors.blue,
                  flex: flexs[0],
                  label: isPinned ? StrRes.cancelTop : StrRes.top,
                  onPressed: () {
                    logic.setPinnedConversation(
                        info, !(info.isPinned ??= false));
                  }),
              if (unReadCount > 0)
                CustomSlidableAction(
                    backgroundColor: Styles.c_707070,
                    flex: flexs[1],
                    label: StrRes.markHasRead,
                    onPressed: () {
                      logic.setReadConversation(info);
                    }),
              CustomSlidableAction(
                  backgroundColor: Colors.red,
                  flex: flexs[2],
                  label: StrRes.delete,
                  onPressed: () {
                    logic.removeConversation(info);
                  }),
            ]),
        child: Ink(
          child: InkWell(
            onTap: () => logic.toChat(conversationInfo: info),
            child: Stack(
              children: [
                Visibility(
                    visible: info.isPinned ?? false,
                    child: Positioned(
                        top: 0,
                        right: 4,
                        child: CustomPaint(
                          size: const Size(10, 10),
                          painter: TrianglePainter(color: Styles.c_0089FF),
                        ))),
                Container(
                  height: 68,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          AvatarView(
                            width: 48.w,
                            height: 48.h,
                            text: logic.getShowName(info),
                            url: _logConversationAvatar(info),
                            isGroup: logic.isGroupChat(info),
                            textStyle: Styles.ts_FFFFFF_14sp_medium,
                          ),
                        ],
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 180.w),
                                  child: logic.getShowName(info).toText
                                    ..style = Styles.ts_0C1C33_17sp
                                    ..maxLines = 1
                                    ..overflow = TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                logic.getTime(info).toText
                                  ..style = Styles.ts_8E9AB0_12sp,
                              ],
                            ),
                            3.verticalSpace,
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
                                                  text:
                                                      '[${sprintf(StrRes.nPieces, [
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
                                  ImageRes.notDisturb.toImage..width = 12.w,
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
          ),
        ));
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      child: SearchBox(
        enabled: false,
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      ),
      onTap: () => logic.toSearch(),
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

class CustomSlidableAction extends StatelessWidget {
  final Color backgroundColor;
  final String label;
  final int flex;
  final Function? onPressed;

  const CustomSlidableAction(
      {super.key,
      required this.backgroundColor,
      required this.label,
      this.flex = 1,
      this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Flexible(
        flex: flex,
        child: SizedBox.expand(
          child: GestureDetector(
            onTap: () {
              onPressed?.call();
              Slidable.of(context)?.close();
            },
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
              ),
              child: Center(
                child: Text(label, style: Styles.ts_FFFFFF_14sp),
              ),
            ),
          ),
        ));
  }
}
