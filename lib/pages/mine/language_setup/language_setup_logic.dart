import 'dart:ui';

import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class LanguageSetupLogic extends GetxController {
  final isFollowSystem = false.obs;
  final isChinese = false.obs;
  final isEnglish = false.obs;
  final isTraditionalChinese = false.obs;

  @override
  void onInit() {
    _initLanguageSetting();
    super.onInit();
  }

  void _initLanguageSetting() {
    var language = DataSp.getLanguage() ?? 0;
    switch (language) {
      case 1:
        isFollowSystem.value = false;
        isChinese.value = true;
        isEnglish.value = false;
        isTraditionalChinese.value = false;
        break;
      case 2:
        isFollowSystem.value = false;
        isChinese.value = false;
        isEnglish.value = true;
        isTraditionalChinese.value = false;
        break;
      case 3:
        isFollowSystem.value = false;
        isChinese.value = false;
        isEnglish.value = false;
        isTraditionalChinese.value = true;
        break;
      default:
        isFollowSystem.value = true;
        isChinese.value = false;
        isEnglish.value = false;
        isTraditionalChinese.value = false;
        break;
    }
  }

  /// 根据系统语言获取对应的应用语言设置
  Locale _getSystemMappedLocale() {
    final systemLocale = Get.deviceLocale;
    if (systemLocale == null) {
      // 如果无法获取系统语言，默认使用中文
      return const Locale('zh', 'CN');
    }
    
    final languageCode = systemLocale.languageCode.toLowerCase();
    final countryCode = systemLocale.countryCode?.toUpperCase();
    
    // 根据系统语言映射到应用支持的语言
    if (languageCode == 'zh') {
      if (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO') {
        // 繁体中文地区
        return const Locale('zh', 'HK');
      } else {
        // 简体中文地区
        return const Locale('zh', 'CN');
      }
    } else if (languageCode == 'en') {
      return const Locale('en', 'US');
    } else {
      // 其他语言默认使用英文
      return const Locale('en', 'US');
    }
  }

  void switchLanguage(index) async {
    await DataSp.putLanguage(index);
    switch (index) {
      case 1:
        isFollowSystem.value = false;
        isChinese.value = true;
        isEnglish.value = false;
        isTraditionalChinese.value = false;
        Get.updateLocale(const Locale('zh', 'CN'));
        break;
      case 2:
        isFollowSystem.value = false;
        isChinese.value = false;
        isEnglish.value = true;
        isTraditionalChinese.value = false;
        Get.updateLocale(const Locale('en', 'US'));
        break;
      case 3:
        isFollowSystem.value = false;
        isChinese.value = false;
        isEnglish.value = false;
        isTraditionalChinese.value = true;
        Get.updateLocale(const Locale('zh', 'HK'));
        break;
      default:
        isFollowSystem.value = true;
        isChinese.value = false;
        isEnglish.value = false;
        isTraditionalChinese.value = false;
        // 跟随系统：获取系统语言并映射到应用支持的语言
        final mappedLocale = _getSystemMappedLocale();
        Get.updateLocale(mappedLocale);
        break;
    }
  }
}
