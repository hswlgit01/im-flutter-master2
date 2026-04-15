import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim/routes/app_navigator.dart';

class CardMessageView extends StatelessWidget {
  final Message message;
  final bool isSelf;
  final Function()? onTap;

  const CardMessageView({
    Key? key,
    required this.message,
    required this.isSelf,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardElem = message.cardElem;
    if (cardElem == null) return const SizedBox();

    return GestureDetector(
      onTap: onTap ?? () {
        // 如果没有提供 onTap 回调，则使用默认行为
        if (message.contentType == MessageType.card) {
          // 创建 UserInfo 对象
          UserInfo userInfo = UserInfo()
            ..userID = cardElem.userID
            ..nickname = cardElem.nickname
            ..faceURL = cardElem.faceURL;
          
          // 跳转到用户信息页面
          AppNavigator.startUserProfilePane(
            userID: userInfo.userID!,
            nickname: userInfo.nickname,
            faceURL: userInfo.faceURL,
            forceCanAdd: true,
          );
        }
      },
      child: Container(
        width: 220.w,
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelf 
              ? [
                  Styles.c_0089FF.withOpacity(0.05),
                  Styles.c_0089FF.withOpacity(0.08),
                ]
              : [
                  Colors.white,
                  Colors.grey.shade50,
                ],
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelf 
              ? Styles.c_0089FF.withOpacity(0.15)
              : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: isSelf 
                ? Styles.c_0089FF.withOpacity(0.05)
                : Colors.grey.shade200,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                  BoxShadow(
                    color: isSelf 
                      ? Styles.c_0089FF.withOpacity(0.08)
                      : Colors.grey.shade300,
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: AvatarView(
                  url: cardElem.faceURL,
                  text: cardElem.nickname,
                  width: 40.w,
                  height: 40.h,
                  textStyle: Styles.ts_FFFFFF_14sp,
                ),
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  (cardElem.nickname ?? '').toText
                    ..style = TextStyle(
                      color: isSelf ? Styles.c_0C1C33 : Colors.grey.shade800,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  4.verticalSpace,
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isSelf 
                          ? [
                              Styles.c_0089FF.withOpacity(0.1),
                              Styles.c_0089FF.withOpacity(0.15),
                            ]
                          : [
                              Colors.grey.shade100,
                              Colors.grey.shade200,
                            ],
                      ),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 10.w,
                          color: isSelf ? Styles.c_0089FF : Colors.grey.shade600,
                        ),
                        4.horizontalSpace,
                        StrRes.carte.toText
                          ..style = TextStyle(
                            color: isSelf ? Styles.c_0089FF : Colors.grey.shade600,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelf 
                    ? [
                        Styles.c_0089FF.withOpacity(0.1),
                        Styles.c_0089FF.withOpacity(0.15),
                      ]
                    : [
                        Colors.grey.shade100,
                        Colors.grey.shade200,
                      ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 10.w,
                color: isSelf ? Styles.c_0089FF : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 