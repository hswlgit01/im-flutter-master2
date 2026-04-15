// 由 tool/sync_brand.dart 根据 brand.properties 生成，请勿手改。
// 修改品牌信息请编辑项目根目录 brand.properties 后执行: dart run tool/sync_brand.dart

class AppBrand {
  AppBrand._();

  /// Android applicationId，与 Gradle 中一致
  static const String applicationId = 'com.flutterOpenIM2.app';

  /// iOS Bundle ID（与 Xcode 中 PRODUCT_BUNDLE_IDENTIFIER 一致）
  static const String iosBundleId = 'com.flutterOpenIM2.app';

  /// 个推 AppId（与 Android manifestPlaceholders 中 GETUI_APPID 一致）
  static const String getuiAppId = 'u7XipjV3Dt6qDLMhwRE8U2';

  /// 渠道 ID（分发/统计）
  static const String channelId = 'official';

  /// Shorebird app_id（与 shorebird.yaml 一致）
  static const String shorebirdAppId =
      'af3b7de6-8fe4-4499-9fc8-a46c2bdd8f10';
}
