import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:flutter/material.dart';
import 'package:openim_common/src/models/payment_method.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';

class PaymentMethodLogic extends GetxController {
  final isLoading = false.obs;
  final paymentMethods = <PaymentMethod>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadPaymentMethods();
  }

  /// 加载支付方式列表
  Future<void> loadPaymentMethods() async {
    try {
      isLoading.value = true;
      paymentMethods.value = await Apis.getPaymentMethods();
    } catch (e) {
      IMViews.showToast('加载失败: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// 设置默认支付方式
  Future<void> setDefault(String paymentMethodId) async {
    try {
      await Apis.setDefaultPaymentMethod(paymentMethodId);
      await loadPaymentMethods(); // 刷新列表
      IMViews.showToast(StrRes.setSuccessfully);
    } catch (e) {
      IMViews.showToast('设置失败: $e');
    }
  }
  
  /// 选择图片
  Future<File?> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      IMViews.showToast('选择图片失败: $e');
      return null;
    }
  }
  
  /// 删除支付方式
  Future<void> deletePaymentMethod(String id) async {
    try {
      // 显示确认对话框
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          title: Text(StrRes.confirmDeletePayment),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(StrRes.cancel),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: Text(StrRes.confirm, style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      // 如果用户确认删除
      if (confirm == true) {
        await Apis.deletePaymentMethod(id);
        paymentMethods.removeWhere((method) => method.id == id);
        IMViews.showToast(StrRes.deleteSuccess);
      }
    } catch (e) {
      IMViews.showToast('${StrRes.deleteFailed}: $e');
    }
  }
  
  /// 添加银行卡
  Future<void> addBankCard({
    required String bankName,
    required String cardNumber,
    required String branchName,
    required String accountName,
    required bool setAsDefault,
  }) async {
    try {
      isLoading.value = true;

      final newMethod = await Apis.addBankCard(
        cardNumber: cardNumber,
        bankName: bankName,
        branchName: branchName,
        accountName: accountName,
        isDefault: setAsDefault || paymentMethods.isEmpty,
      );

      paymentMethods.add(newMethod);
      Get.back();
      IMViews.showToast('添加成功');
    } catch (e) {
      IMViews.showToast('添加失败: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  /// 添加二维码支付方式
  Future<void> addQRCode({
    required PaymentMethodType type,
    required File qrCodeImage,
    required String accountName,
    required bool setAsDefault,
  }) async {
    try {
      isLoading.value = true;

      // 第一步：使用 OpenIM SDK 上传图片
      final fileName = qrCodeImage.path.split('/').last;
      final putID = DateTime.now().millisecondsSinceEpoch.toString();

      final uploadResult = await OpenIM.iMManager.uploadFile(
        id: putID,
        filePath: qrCodeImage.path,
        fileName: fileName,
      );

      // 上传结果是一个 Map，包含 url 字段
      String? imageUrl;
      if (uploadResult is Map) {
        imageUrl = uploadResult['url'] ?? uploadResult['URL'];
      } else if (uploadResult is String) {
        // 如果返回的直接是字符串
        try {
          final jsonData = json.decode(uploadResult);
          if (jsonData is Map) {
            imageUrl = jsonData['url'] ?? jsonData['URL'];
          } else {
            imageUrl = uploadResult;
          }
        } catch (e) {
          imageUrl = uploadResult;
        }
      }

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('上传失败：未获取到图片URL');
      }

      // 第二步：创建支付方式记录
      final newMethod = await Apis.addQRCodePayment(
        type: type,
        qrCodeUrl: imageUrl,
        accountName: accountName,
        isDefault: setAsDefault || paymentMethods.isEmpty,
      );

      paymentMethods.add(newMethod);
      Get.back();
      IMViews.showToast('添加成功');
    } catch (e) {
      IMViews.showToast('添加失败: $e');
    } finally {
      isLoading.value = false;
    }
  }
}