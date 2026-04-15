import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class SyncStatusView extends StatelessWidget {
  const SyncStatusView({
    Key? key,
    required this.isFailed,
    required this.statusStr,
    this.onTap,
  }) : super(key: key);
  final bool isFailed;
  final String statusStr;
  /// 同步失败时可点击重试，传入此回调（如 conversation_logic.onRetrySync）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Logger.print('Sync Status View: $isFailed, $statusStr');
    final content = Container(
      padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: isFailed ? Styles.c_FFE1DD : Styles.c_F2F8FF,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isFailed
              ? (ImageRes.syncFailed.toImage
                ..width = 12.w
                ..height = 12.h)
              : SizedBox(
                  width: 12.w,
                  height: 12.h,
                  child: CupertinoActivityIndicator(
                    color: Styles.c_0089FF,
                    radius: 6.r,
                  ),
                ),
          4.horizontalSpace,
          statusStr.toText..style = (isFailed ? Styles.ts_FF381F_12sp : Styles.ts_0089FF_12sp),
        ],
      ),
    );
    if (isFailed && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}
