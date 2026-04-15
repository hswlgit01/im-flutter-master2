import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:path_provider/path_provider.dart';

class RuleDescriptionLogic extends GetxController {
  final loading = true.obs;
  final error = false.obs;
  final errorMessage = ''.obs;
  final htmlFilePath = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchCheckinRuleDescription();
  }

  // 获取签到规则说明
  Future<void> fetchCheckinRuleDescription() async {
    loading.value = true;
    error.value = false;
    errorMessage.value = '';

    try {
      // 获取组织信息，其中包含签到规则说明
      final response = await Apis.getOrganizationInfo();

      // 检查是否有签到规则说明
      final checkinRuleDescription = response['checkin_rule_description'];

      if (checkinRuleDescription == null || checkinRuleDescription.toString().isEmpty) {
        // 如果没有签到规则说明，显示提示
        error.value = true;
        errorMessage.value = StrRes.noData;
        loading.value = false;
        return;
      }

      // 构建HTML内容
      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
      padding: 16px;
      margin: 0;
      color: #333;
      line-height: 1.5;
    }
    img {
      max-width: 100%;
      height: auto;
    }
  </style>
</head>
<body>
  $checkinRuleDescription
</body>
</html>
      ''';

      // 创建临时文件存储HTML内容
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/checkin_rule.html';
      final file = File(filePath);
      await file.writeAsString(htmlContent);

      htmlFilePath.value = filePath;
      loading.value = false;
    } catch (e) {
      error.value = true;
      errorMessage.value = '${StrRes.loadFailedSimple}: $e';
      loading.value = false;
      Logger.print('加载签到规则失败: $e');
    }
  }

  // 重试加载
  void retry() {
    fetchCheckinRuleDescription();
  }
}