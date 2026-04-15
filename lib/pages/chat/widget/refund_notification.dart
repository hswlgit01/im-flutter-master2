import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class RefundNotification extends StatelessWidget {
  final Message message;

  const RefundNotification({super.key, required this.message});

  RefundDataDetails? get refundNotificationData {
    if (message.contentType == MessageType.custom) {
      if (message.customElem == null) {
        return null;
      }
      return RefundData.fromJsonString(message.customElem!.data!).data;
    } else if (message.contentType == MessageType.oaNotification) {
      var notifyContent = NotifyContent.fromJson(
          jsonDecode(message.notificationElem?.detail ?? ''));
      return notifyContent.refundElem;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (refundNotificationData == null) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        border: Border.all(color: Styles.c_E8EAEF, width: 1),
        borderRadius: BorderRadius.all(Radius.circular(8.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
                border: Border(
              top: BorderSide(
                color: Styles.c_E8EAEF,
                width: 1,
              ),
            )),
            child: Column(
              children: [
                _buildAmount(),
                20.verticalSpace,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttribute(
                      title: StrRes.refundType,
                      value:
                          _formatRefundType(refundNotificationData!.refundType),
                    ),
                    10.verticalSpace,
                    _buildAttribute(
                        title: StrRes.refundMethod,
                        right: Text(StrRes.returnedToWallet,
                            style: Styles.ts_0089FF_14sp)),
                    10.verticalSpace,
                    _buildAttribute(
                      title: StrRes.timeCredited,
                      value: IMUtils.formatDate(
                          refundNotificationData!.refundTime * 1000),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  String _formatRefundType(int type) {
    switch (type) {
      case 2:
        return StrRes.transferRefund;
      case 11:
        return StrRes.redPacketRefund;
      default:
        return StrRes.unknownType;
    }
  }

  Widget _buildAttribute(
      {required String title, String? value, Widget? right}) {
    var rightWidget = right ?? Text(value ?? "");
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Styles.ts_8E9AB0_14sp),
        8.horizontalSpace,
        Expanded(
          child: rightWidget,
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: EdgeInsets.all(12.w),
      child: Text(
        StrRes.refundNotification,
        style: Styles.ts_0C1C33_14sp_medium,
      ),
    );
  }

  Widget _buildAmount() {
    return Column(
      children: [
        Text(StrRes.refundAmount, style: Styles.ts_8E9AB0_14sp),
        4.verticalSpace,
        Text(
          "${IMUtils.getCurrencySymbol(refundNotificationData!.currency)} ${IMUtils.formatNumberWithCommas(refundNotificationData!.amount)}",
          style: TextStyle(
            color: Styles.c_FFB300,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
