import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import './wallet_logic.dart';
import 'bill/bill_detail/bill_detail_view.dart';
import 'compensation_records/compensation_records_view.dart';

class _WalletPage extends StatelessWidget {
  // 使用find()获取已存在的实例，而不是创建新实例
  final logic = Get.find<WalletLogic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StrRes.walletTitle.toText..style = Styles.ts_0C1C33_17sp_medium,
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
        actions: [
          GestureDetector(
            onTap: logic.viewWithdrawalRecords,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Center(
                child: Text(
                  '提现记录',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Styles.c_0089FF,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() => Column(
            children: [
              if (logic.isWalletActivated) ...[
                _buildBalanceCard(),
                _buildOperationButtons(),
                _buildTransactionList(),
              ] else
                _buildActivateWallet(),
            ],
          )),
    );
  }

  // 未激活钱包时的UI
  Widget _buildActivateWallet() => Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 80.w,
                color: Styles.c_0089FF,
              ),
              24.verticalSpace,
              StrRes.walletTitle.toText..style = Styles.ts_0C1C33_20sp_medium,
              16.verticalSpace,
              Container(
                width: 200.w,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: logic.walletController.activateWallet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles.c_0089FF,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: StrRes.walletActivate.toText
                    ..style = Styles.ts_FFFFFF_16sp,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildBalanceCard() => Container(
        padding: EdgeInsets.all(16.w),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StrRes.walletBalance.toText..style = Styles.ts_8E9AB0_14sp,
            8.verticalSpace,
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Obx(() => Text(
                      logic.balance.value,
                      style: Styles.ts_0C1C33_24sp_medium,
                    )),
                4.horizontalSpace,
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: Text(
                    "U",
                    style: Styles.ts_0C1C33_17sp,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildOperationButtons() => Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            //_buildOperationButton(
            //  icon: Icons.add_circle_outline,
            //  text: StrRes.walletRecharge,
            //  onTap: logic.recharge,
            //),
            _buildOperationButton(
              icon: Icons.remove_circle_outline,
              text: StrRes.walletWithdraw,
              onTap: logic.withdraw,
            ),
            _buildOperationButton(
              icon: Icons.receipt_long_outlined,
              text: '提现记录',
              onTap: logic.viewWithdrawalRecords,
            ),
          ],
        ),
      );

  Widget _buildOperationButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24.w, color: Styles.c_0C1C33),
            4.verticalSpace,
            text.toText..style = Styles.ts_0C1C33_14sp,
          ],
        ),
      );

  Widget _buildTransactionList() => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StrRes.walletTransactionRecord.toText
                    ..style = Styles.ts_0C1C33_17sp_medium,
                  GestureDetector(
                    // onTap: logic.viewBill,
                    child: StrRes.walletViewAll.toText
                      ..style = Styles.ts_0089FF_14sp,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(
                () => logic.transactions.isEmpty
                    ? Center(
                        child: Text(
                          StrRes.walletNoMoreData,
                          style: Styles.ts_8E9AB0_14sp,
                        ),
                      )
                    : ListView.builder(
                        itemCount: logic.transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = logic.transactions[index];
                          return _buildTransactionItem(transaction);
                        },
                      ),
              ),
            ),
          ],
        ),
      );

  String _getTransactionTypeText(int type) {
    switch (type) {
      case 1:
        return StrRes.transferExpense;
      case 2:
        return StrRes.transferRefund;
      case 3:
        return StrRes.transferReceipt;
      case 11:
        return StrRes.redPacketRefund;
      case 12:
        return StrRes.redPacketExpense;
      case 13:
        return StrRes.redPacketReceipt;
      case 21:
        return StrRes.recharge;
      case 22:
        return StrRes.withdraw;
      case 23:
        return StrRes.consumption;
      case 42:
        return StrRes.checkinReward;
      default:
        return StrRes.unknownType;
    }
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) =>
      GestureDetector(
        onTap: () =>
            Get.to(() => BillDetailPage(), arguments: {'bill': transaction}),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Styles.c_E8EAEF, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTransactionTypeText(transaction['type'] ?? 0),
                      style: Styles.ts_0C1C33_14sp,
                    ),
                    4.verticalSpace,
                    Text(
                      transaction['transaction_time']?.toString() ?? '',
                      style: Styles.ts_8E9AB0_12sp,
                    ),
                    4.verticalSpace,
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction['amount']} CNY',
                    style: Styles.ts_0C1C33_17sp_medium,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class WalletPage extends StatefulWidget {
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with WidgetsBindingObserver {
  final logic = Get.put(WalletLogic());

  @override
  void initState() {
    super.initState();
    // 注册生命周期观察者
    WidgetsBinding.instance.addObserver(this);
    // 页面初始创建时调用页面可见方法
    logic.onPageVisible();
  }

  @override
  void dispose() {
    // 取消生命周期观察者注册
    WidgetsBinding.instance.removeObserver(this);
    // 页面销毁时调用页面不可见方法
    logic.onPageInvisible();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 处理应用程序生命周期状态变化
    if (state == AppLifecycleState.resumed) {
      // 应用程序回到前台
      logic.onPageVisible();
    } else if (state == AppLifecycleState.paused) {
      // 应用程序进入后台
      logic.onPageInvisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StrRes.walletTitle.toText..style = Styles.ts_0C1C33_17sp_medium,
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
        actions: [
          GestureDetector(
            onTap: logic.viewWithdrawalRecords,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Center(
                child: Text(
                  '提现记录',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Styles.c_0089FF,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() => Container(
            color: Styles.c_FFFFFF,
            child: Column(
              children: [
                if (logic.isWalletActivated) ...[
                  Expanded(
                      child: SmartRefresher(
                    controller: logic.refreshController,
                    enablePullUp: false,
                    header: IMViews.buildHeader(),
                    footer: IMViews.buildFooter(),
                    onRefresh: logic.onRefresh,
                    child: SingleChildScrollView(
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          children: [
                            _buildHeader(),
                            _buildTokenList(),
                          ],
                        ),
                      ),
                    ),
                  )),
                  Divider(height: 1, color: Styles.c_E8EAEF),
                  _buildBottomArea(),
                ] else
                  _buildActivateWallet(),
              ],
            ),
          )),
    );
  }

  // 未激活钱包时的UI
  Widget _buildActivateWallet() => Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 80.w,
                color: Styles.c_0089FF,
              ),
              24.verticalSpace,
              StrRes.walletTitle.toText..style = Styles.ts_0C1C33_20sp_medium,
              16.verticalSpace,
              Container(
                width: 200.w,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: logic.walletController.activateWallet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles.c_0089FF,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: StrRes.walletActivate.toText
                    ..style = Styles.ts_FFFFFF_16sp,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildBottomArea() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          //Expanded(
          //  child: TextButton(
          //    onPressed: () async {
          //      logic.recharge();
          //    },
          //    style: TextButton.styleFrom(
          //      backgroundColor: Styles.c_0089FF,
          //      padding: EdgeInsets.symmetric(vertical: 12.h),
          //      shape: RoundedRectangleBorder(
          //        borderRadius: BorderRadius.circular(6.r),
          //      ),
          //    ),
          //    child: Row(
          //      mainAxisAlignment: MainAxisAlignment.center,
          //      children: [
          //        const Icon(
          //         Icons.add,
          //          color: Colors.white,
          //        ),
          //        StrRes.walletRecharge.toText..style = Styles.ts_FFFFFF_17sp
          //     ],
          //    ),
          //  ),
          //),
          //10.horizontalSpace,
          Expanded(
            child: TextButton(
              onPressed: () async {
                logic.withdraw();
              },
              style: TextButton.styleFrom(
                backgroundColor: Styles.c_F0F2F6,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_outward_outlined,
                    color: Styles.c_0C1C33,
                  ),
                  StrRes.walletWithdraw.toText..style = Styles.ts_0C1C33_17sp
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 注释掉或移除组织选择框和货币选择框
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     // 组织下拉框
        //     Container(
        //       padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        //       decoration: BoxDecoration(
        //           color: Styles.c_F0F2F6,
        //           borderRadius: BorderRadius.all(Radius.circular(8.r))),
        //       child: GestureDetector(
        //         onTap: () => logic.selectOrg(),
        //         child: Row(
        //           children: [
        //             Text(logic.walletController.currentOrg.organization?.name ?? ''),
        //             Icon(Icons.keyboard_arrow_down_rounded, size: 14.w)
        //           ],
        //         ),
        //       ),
        //     ),
        //     // 货币下拉框
        //     Container(
        //       padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        //       decoration: BoxDecoration(
        //           color: Styles.c_F0F2F6,
        //           borderRadius: BorderRadius.all(Radius.circular(8.r))),
        //       child: GestureDetector(
        //         onTap: () => logic.selectCurrency(),
        //         child: Row(
        //           children: [
        //             Text(logic.currency.value),
        //             if (logic.exchageRateInfoIsLoading.value)
        //               Container(
        //                 width: 10.w,
        //                 height: 10.w,
        //                 margin: EdgeInsets.only(left: 4.w),
        //                 child: CircularProgressIndicator(
        //                   strokeWidth: 2.w,
        //                 ),
        //               )
        //             else
        //               Icon(Icons.keyboard_arrow_down_rounded, size: 14.w)
        //           ],
        //         ),
        //       ),
        //     )
        //   ],
        // ),
        // 16.verticalSpace,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 余额标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右两侧对齐
                children: [
                  // 左侧 - 钱包余额标题
                  Text(
                    StrRes.walletBalance,
                    style: Styles.ts_8E9AB0_13sp,
                  ),

                  // 右侧 - 补偿金余额标题
                  if (logic.walletController.balanceDetail.value?.compensationBalance != null)
                    Text(
                      StrRes.walletCompensationBalance,
                      style: Styles.ts_8E9AB0_13sp,
                    ),
                ],
              ),

              8.verticalSpace,

              // 余额显示行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右两侧对齐
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 左侧 - 主余额
                  Text(
                    logic.totalBalance, // 只显示数值，不显示单位
                    style: Styles.ts_0C1C33_24sp_medium,
                  ),

                  // 右侧 - 补偿金余额
                  if (logic.walletController.balanceDetail.value?.compensationBalance != null)
                    GestureDetector(
                      onTap: () {
                        // 跳转到补偿金记录页面
                        Get.to(() => CompensationRecordsPage());
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            IMUtils.formatNumberWithCommas(
                              logic.walletController.balanceDetail.value!.compensationBalance!.isEmpty
                                ? '0.00'
                                : logic.walletController.balanceDetail.value!.compensationBalance!
                            ),
                            style: TextStyle(fontSize: 20.sp, color: Styles.c_0089FF, fontWeight: FontWeight.w500),
                          ),
                          4.horizontalSpace,
                          Icon(Icons.chevron_right, size: 16.w, color: Styles.c_0089FF),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          )
        ],
      );
    });
  }

  Widget _buildTokenList() {
    return Container(
      padding: EdgeInsets.only(top: 16.h),
      child: Column(
        children: [
          ...List.generate(logic.walletController.balanceDetail.value?.currency?.length ?? 0,
              (i) {
            final item = logic.walletController.balanceDetail.value!.currency![i];

            return TokenItem(
              tokenIconUrl: item.currencyInfo?.icon ?? '',
              tokenAmount:
                  IMUtils.formatNumberWithCommas(item.balanceInfo?.availableBalance ?? '0.00'),
              tokenName: item.currencyInfo?.name ?? '',
              exchangeRateText:
                  '${StrRes.exchangeRate}: 1 ${item.currencyInfo?.name} = ${IMUtils.formatNumberWithCommas(num.parse(item.currencyInfo?.exchangeRate ?? "0") * logic.rate.value)} ${logic.currency.value}',
              tokenValue:
                  IMUtils.formatNumberWithCommas(num.parse(item.balanceInfo?.balanceToUsd ?? '0') * logic.rate.value),
              onTap: () => logic.viewBill(item),
            );
          }),
        ],
      ),
    );
  }
}

class TokenItem extends StatefulWidget {
  final String tokenIconUrl;
  final String tokenName;
  final String tokenAmount;
  final String tokenValue;
  final String exchangeRateText;
  final Function()? onTap;

  const TokenItem({
    super.key,
    required this.tokenName,
    required this.tokenAmount,
    required this.tokenValue,
    required this.tokenIconUrl,
    required this.exchangeRateText,
    this.onTap,
  });

  @override
  State<TokenItem> createState() => _TokenItemState();
}

class _TokenItemState extends State<TokenItem> {
  Color? backgroundColor;
  // 使用find()获取已存在的实例，而不是创建新实例
  final logic = Get.find<WalletLogic>();

  @override
  void initState() {
    super.initState();
    _loadImageColor();
  }

  Future<void> _loadImageColor() async {
    final imageProvider = CachedNetworkImageProvider(UrlConverter.convertMediaUrl(widget.tokenIconUrl));

    final color = await getImagePalette(imageProvider);
    if (mounted) {
      setState(() {
        // 使用带透明度的颜色，使其更适合作为背景
        backgroundColor = color.withOpacity(0.1);
      });
    }
  }

  Future<Color> getImagePalette(ImageProvider imageProvider) async {
    final PaletteGenerator paletteGenerator =
        await PaletteGenerator.fromImageProvider(imageProvider);
    return paletteGenerator.vibrantColor?.color ??
        paletteGenerator.dominantColor?.color ??
        Colors.blue.shade50;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onTap?.call(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(8.r)),
        ),
        child: Row(
          children: [
            // 币种Logo
            widget.tokenIconUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: UrlConverter.convertMediaUrl(widget.tokenIconUrl),
                    width: 32.w,
                    height: 32.w,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.currency_exchange,
                        size: 20.w,
                        color: Colors.grey[400],
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.currency_exchange,
                        size: 20.w,
                        color: Colors.grey[400],
                      ),
                    ),
                    imageBuilder: (context, imageProvider) => Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.currency_exchange,
                      size: 20.w,
                      color: Colors.grey[400],
                    ),
                  ),
            12.horizontalSpace,
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.tokenName,
                    style: Styles.ts_0C1C33_17sp_medium,
                  ),
                  Text(
                    widget.tokenAmount,
                    style: Styles.ts_0C1C33_17sp_medium,
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
