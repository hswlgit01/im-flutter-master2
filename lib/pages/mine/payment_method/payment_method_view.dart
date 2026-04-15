import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:openim_common/src/models/payment_method.dart';

import 'payment_method_logic.dart';

class PaymentMethodPage extends StatelessWidget {
  final logic = Get.put(PaymentMethodLogic());

  PaymentMethodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.back(title: StrRes.paymentMethod),
      backgroundColor: Styles.c_F8F9FA,
      body: Obx(() => logic.isLoading.value
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildAddButtons(),
                16.verticalSpace,
                Expanded(
                  child: logic.paymentMethods.isEmpty
                      ? _buildEmptyView()
                      : _buildPaymentMethodList(),
                ),
              ],
            )),
    );
  }

  // 添加按钮区域
  Widget _buildAddButtons() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StrRes.addPaymentMethod,
            style: Styles.ts_0C1C33_16sp_medium,
          ),
          16.verticalSpace,
          Row(
            children: [
              Expanded(
                child: _buildAddButton(
                  icon: Icons.credit_card,
                  text: StrRes.addBankCard,
                  onTap: () => _showAddBankCardDialog(),
                  color: Styles.c_0089FF,
                ),
              ),
              16.horizontalSpace,
              Expanded(
                child: _buildAddButton(
                  icon: Icons.qr_code,
                  text: StrRes.addQRCode,
                  onTap: () => _showAddQRCodeDialog(),
                  color: Styles.c_34C759,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.w),
            8.verticalSpace,
            Text(
              text,
              style: TextStyle(color: color, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }

  // 空状态
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80.w,
            color: Styles.c_8E9AB0,
          ),
          16.verticalSpace,
          Text(
            StrRes.noPaymentMethods,
            style: Styles.ts_8E9AB0_16sp,
          ),
          8.verticalSpace,
          Text(
            StrRes.clickToAddPaymentMethod,
            style: Styles.ts_8E9AB0_14sp,
          ),
        ],
      ),
    );
  }

  // 收款方式列表
  Widget _buildPaymentMethodList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: logic.paymentMethods.length,
      itemBuilder: (context, index) {
        final method = logic.paymentMethods[index]; // 直接使用 PaymentMethod 对象
        return _buildPaymentMethodItem(method);
      },
    );
  }

  Widget _buildPaymentMethodItem(PaymentMethod method) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Styles.c_FFFFFF,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 图标
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: _getMethodColor(method.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  _getMethodIcon(method.type),
                  color: _getMethodColor(method.type),
                  size: 20.w,
                ),
              ),
              12.horizontalSpace,
              // 标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getMethodTitle(method.type),
                      style: Styles.ts_0C1C33_16sp_medium,
                    ),
                    if (method.type == PaymentMethodType.bankCard && method.bankName != null)
                      Text(
                        method.bankName!,
                        style: Styles.ts_8E9AB0_12sp,
                      ),
                  ],
                ),
              ),
              // 默认标识
              if (method.isDefault)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Styles.c_0089FF.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    StrRes.defaulticon,
                    style: TextStyle(color: Styles.c_0089FF, fontSize: 10.sp),
                  ),
                ),
            ],
          ),
          
          12.verticalSpace,
          
          // 具体信息
          _buildMethodDetails(method),
          
          12.verticalSpace,
          
          // 操作按钮
          Row(
            children: [
              if (!method.isDefault)
                Expanded(
                  child: TextButton(
                    onPressed: () => logic.setDefault(method.id!),
                    style: TextButton.styleFrom(
                      backgroundColor: Styles.c_F0F2F6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                    child: Text(
                      StrRes.setAsDefault,
                      style: Styles.ts_0C1C33_14sp,
                    ),
                  ),
                ),
              if (!method.isDefault) 16.horizontalSpace,
              Expanded(
                child: TextButton(
                  onPressed: () => logic.deletePaymentMethod(method.id!),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                  child: Text(
                    StrRes.delete,
                    style: TextStyle(color: Colors.red, fontSize: 14.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodDetails(PaymentMethod method) {
  switch (method.type) {
    case PaymentMethodType.bankCard:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailItem(StrRes.accountHolder, method.accountName ?? ''),
          _buildDetailItem(StrRes.cardNo, method.cardNumber ?? ''),
          if (method.branchName != null)
            _buildDetailItem(StrRes.branchName, method.branchName!),
        ],
      );
    case PaymentMethodType.wechat:
    case PaymentMethodType.alipay:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailItem(StrRes.accountName, method.accountName ?? ''),
          if (method.qrCodeUrl != null)
            Container(
              margin: EdgeInsets.only(top: 8.h),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  width: 120.w,
                  height: 120.w,
                  color: Styles.c_F0F2F6,
                  child: Image.network(
                    UrlConverter.convertMediaUrl(method.qrCodeUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 30.w),
                            4.verticalSpace,
                            Text(
                              '图片加载失败',
                              style: TextStyle(fontSize: 10.sp, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      );
  }
}

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60.w,
            child: Text(
              '$label：',
              style: Styles.ts_8E9AB0_12sp,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Styles.ts_0C1C33_12sp,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMethodIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.bankCard:
        return Icons.credit_card;
      case PaymentMethodType.wechat:
        return Icons.wechat;
      case PaymentMethodType.alipay:
        return Icons.payment;
    }
  }

  Color _getMethodColor(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.bankCard:
        return Styles.c_0089FF;
      case PaymentMethodType.wechat:
        return Color(0xFF07C160);
      case PaymentMethodType.alipay:
        return Color(0xFF1677FF);
    }
  }

  String _getMethodTitle(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.bankCard:
        return StrRes.bankCard;
      case PaymentMethodType.wechat:
        return StrRes.wechatPayment;
      case PaymentMethodType.alipay:
        return StrRes.alipayPayment;
    }
  }

  // 添加银行卡对话框
  void _showAddBankCardDialog() {
    final bankNameCtrl = TextEditingController();
    final cardNumberCtrl = TextEditingController();
    final branchNameCtrl = TextEditingController();
    final accountNameCtrl = TextEditingController();
    final isDefault = false.obs;
    final isSubmitting = false.obs; // 提交状态

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  StrRes.addBankCard,
                  style: Styles.ts_0C1C33_18sp_medium,
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),

            16.verticalSpace,

            // 银行名称
            _buildInputField(
              controller: bankNameCtrl,
              label: StrRes.bankName,
              hintText: StrRes.inputBankName,
            ),
            12.verticalSpace,

            // 银行卡号
            _buildInputField(
              controller: cardNumberCtrl,
              label: StrRes.cardNumber,
              hintText: StrRes.inputCardNumber,
              keyboardType: TextInputType.number,
            ),
            12.verticalSpace,

            // 开户行
            _buildInputField(
              controller: branchNameCtrl,
              label: StrRes.branchName,
              hintText: StrRes.inputBranchName,
            ),
            12.verticalSpace,

            // 持卡人姓名
            _buildInputField(
              controller: accountNameCtrl,
              label: StrRes.accountHolderName,
              hintText: StrRes.inputHolderName,
            ),
            12.verticalSpace,

            // 设为默认
            Obx(() => Row(
              children: [
                Checkbox(
                  value: isDefault.value,
                  onChanged: isSubmitting.value ? null : (value) => isDefault.value = value!,
                  activeColor: Styles.c_0089FF,
                ),
                Text(StrRes.setAsDefaultPayment, style: Styles.ts_0C1C33_14sp),
              ],
            )),

            16.verticalSpace,

            // 提交状态提示
            Obx(() => isSubmitting.value
                ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
                            ),
                          ),
                          8.horizontalSpace,
                          Text(
                            '提交中，请稍候...',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Styles.c_0089FF,
                            ),
                          ),
                        ],
                      ),
                      12.verticalSpace,
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: LinearProgressIndicator(
                          backgroundColor: Styles.c_E8EAEF,
                          valueColor: AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
                        ),
                      ),
                      12.verticalSpace,
                    ],
                  )
                : SizedBox(height: 8.h)),

            // 确认按钮
            Obx(() => SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isSubmitting.value
                    ? null
                    : () async {
                        if (bankNameCtrl.text.isEmpty ||
                            cardNumberCtrl.text.isEmpty ||
                            branchNameCtrl.text.isEmpty ||
                            accountNameCtrl.text.isEmpty) {
                          IMViews.showToast(StrRes.fillInCompleteInfo);
                          return;
                        }

                        // 设置提交状态
                        isSubmitting.value = true;

                        try {
                          await logic.addBankCard(
                            bankName: bankNameCtrl.text,
                            cardNumber: cardNumberCtrl.text,
                            branchName: branchNameCtrl.text,
                            accountName: accountNameCtrl.text,
                            setAsDefault: isDefault.value,
                          );
                          // 成功后关闭状态（如果对话框还在的话）
                          isSubmitting.value = false;
                        } catch (e) {
                          // 失败后恢复状态
                          isSubmitting.value = false;
                        }
                      },
                style: TextButton.styleFrom(
                  backgroundColor: isSubmitting.value ? Styles.c_8E9AB0 : Styles.c_0089FF,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  isSubmitting.value ? '处理中...' : StrRes.confirmAdd,
                  style: Styles.ts_FFFFFF_16sp,
                ),
              ),
            )),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  // 添加收款码对话框
  void _showAddQRCodeDialog() {
    final type = PaymentMethodType.wechat.obs;
    final accountNameCtrl = TextEditingController();
    final qrCodeImage = Rx<File?>(null);
    final isDefault = false.obs;
    final isUploading = false.obs; // 上传状态

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  StrRes.addQRCode,
                  style: Styles.ts_0C1C33_18sp_medium,
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            
            16.verticalSpace,
            
            // 选择类型
            Text(StrRes.paymentMethod, style: Styles.ts_0C1C33_14sp),
            8.verticalSpace,
            Obx(() => Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    type: PaymentMethodType.wechat,
                    selectedType: type.value,
                    onTap: () => type.value = PaymentMethodType.wechat,
                    icon: Icons.wechat,
                    text: StrRes.wechat,
                    color: Color(0xFF07C160),
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: _buildTypeButton(
                    type: PaymentMethodType.alipay,
                    selectedType: type.value,
                    onTap: () => type.value = PaymentMethodType.alipay,
                    icon: Icons.payment,
                    text: StrRes.alipay,
                    color: Color(0xFF1677FF),
                  ),
                ),
              ],
            )),
            
            16.verticalSpace,
            
            // 账户名
            _buildInputField(
              controller: accountNameCtrl,
              label: StrRes.accountName,
              hintText: StrRes.inputAccountName,
            ),
            
            16.verticalSpace,
            
            // 上传收款码
            Text(StrRes.qrCodeImage, style: Styles.ts_0C1C33_14sp),
            8.verticalSpace,
            Obx(() => GestureDetector(
              onTap: () async {
                final image = await logic.pickImage();
                if (image != null) {
                  qrCodeImage.value = image;
                }
              },
              child: Container(
                width: double.infinity,
                height: 150.h,
                decoration: BoxDecoration(
                  color: Styles.c_F0F2F6,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: Styles.c_E8EAEF,
                    width: 1,
                  ),
                ),
                child: qrCodeImage.value != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.file(
                          qrCodeImage.value!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 40.w, color: Styles.c_8E9AB0),
                          8.verticalSpace,
                          Text(
                            StrRes.clickToUploadQRCode,
                            style: Styles.ts_8E9AB0_14sp,
                          ),
                        ],
                      ),
              ),
            )),
            
            16.verticalSpace,
            
            // 设为默认
            Obx(() => Row(
              children: [
                Checkbox(
                  value: isDefault.value,
                  onChanged: isUploading.value ? null : (value) => isDefault.value = value!,
                  activeColor: Styles.c_0089FF,
                ),
                Text(StrRes.setAsDefaultPayment, style: Styles.ts_0C1C33_14sp),
              ],
            )),

            16.verticalSpace,

            // 上传状态提示
            Obx(() => isUploading.value
                ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
                            ),
                          ),
                          8.horizontalSpace,
                          Text(
                            '图片上传中，请稍候...',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Styles.c_0089FF,
                            ),
                          ),
                        ],
                      ),
                      12.verticalSpace,
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: LinearProgressIndicator(
                          backgroundColor: Styles.c_E8EAEF,
                          valueColor: AlwaysStoppedAnimation<Color>(Styles.c_0089FF),
                        ),
                      ),
                      12.verticalSpace,
                    ],
                  )
                : SizedBox(height: 8.h)),

            // 确认按钮
            Obx(() => SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isUploading.value
                    ? null
                    : () async {
                        if (accountNameCtrl.text.isEmpty) {
                          IMViews.showToast(StrRes.inputAccountName);
                          return;
                        }
                        if (qrCodeImage.value == null) {
                          IMViews.showToast(StrRes.uploadQRCodeImage);
                          return;
                        }

                        // 设置上传状态
                        isUploading.value = true;

                        try {
                          await logic.addQRCode(
                            type: type.value,
                            qrCodeImage: qrCodeImage.value!,
                            accountName: accountNameCtrl.text,
                            setAsDefault: isDefault.value,
                          );
                          // 成功后关闭状态（如果对话框还在的话）
                          isUploading.value = false;
                        } catch (e) {
                          // 失败后恢复状态
                          isUploading.value = false;
                        }
                      },
                style: TextButton.styleFrom(
                  backgroundColor: isUploading.value ? Styles.c_8E9AB0 : Styles.c_0089FF,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  isUploading.value ? '处理中...' : StrRes.confirmAdd,
                  style: Styles.ts_FFFFFF_16sp,
                ),
              ),
            )),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildTypeButton({
    required PaymentMethodType type,
    required PaymentMethodType selectedType,
    required VoidCallback onTap,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    final isSelected = type == selectedType;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Styles.c_F0F2F6,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Styles.c_8E9AB0, size: 24.w),
            8.verticalSpace,
            Text(
              text,
              style: TextStyle(
                color: isSelected ? color : Styles.c_8E9AB0,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Styles.ts_0C1C33_14sp),
        8.verticalSpace,
        Container(
          decoration: BoxDecoration(
            color: Styles.c_F0F2F6,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: Styles.ts_0C1C33_14sp,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: Styles.ts_8E9AB0_14sp,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
            ),
          ),
        ),
      ],
    );
  }
}