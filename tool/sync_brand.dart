// 从项目根目录 brand.properties 同步到 Dart、Shorebird、iOS Bundle ID。
// 用法: dart run tool/sync_brand.dart
//
// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  final root = Directory.current;
  final brandFile = File('${root.path}/brand.properties');
  if (!brandFile.existsSync()) {
    print('未找到 brand.properties，请复制 brand.properties.example 为 brand.properties 并填写。');
    exit(1);
  }

  final props = _parseProperties(brandFile.readAsStringSync());
  final applicationId = props['applicationId']?.trim();
  if (applicationId == null || applicationId.isEmpty) {
    print('brand.properties 中必须设置 applicationId');
    exit(1);
  }

  var iosBundleId = props['iosBundleId']?.trim() ?? '';
  if (iosBundleId.isEmpty) {
    iosBundleId = applicationId;
  }

  final getuiAppId = props['getuiAppId']?.trim() ?? '';
  final channelId = props['channelId']?.trim() ?? 'official';
  final shorebirdAppId = props['shorebirdAppId']?.trim() ?? '';

  final appBrandPath = File('${root.path}/lib/config/app_brand.dart');
  final oldIos = _readExistingIosBundleId(appBrandPath);

  _writeAppBrand(
    appBrandPath,
    applicationId: applicationId,
    iosBundleId: iosBundleId,
    getuiAppId: getuiAppId,
    channelId: channelId,
    shorebirdAppId: shorebirdAppId,
  );

  final shorebirdFile = File('${root.path}/shorebird.yaml');
  if (shorebirdFile.existsSync() && shorebirdAppId.isNotEmpty) {
    var yaml = shorebirdFile.readAsStringSync();
    yaml = yaml.replaceFirst(
      RegExp(r'^app_id:\s*.*$', multiLine: true),
      'app_id: $shorebirdAppId',
    );
    shorebirdFile.writeAsStringSync(yaml);
    print('已更新 shorebird.yaml app_id');
  } else if (shorebirdAppId.isEmpty) {
    print('跳过 shorebird.yaml（未设置 shorebirdAppId）');
  }

  final pbx = File('${root.path}/ios/Runner.xcodeproj/project.pbxproj');
  final prevIos = oldIos ?? 'com.freechat.app';
  if (pbx.existsSync() && prevIos != iosBundleId) {
    final s = pbx.readAsStringSync().replaceAll(prevIos, iosBundleId);
    pbx.writeAsStringSync(s);
    print('已更新 iOS PRODUCT_BUNDLE_IDENTIFIER: $prevIos -> $iosBundleId');
  } else {
    print('iOS Bundle ID 未变更或无需替换（当前: $iosBundleId）');
  }

  print('已生成 lib/config/app_brand.dart');
  print('完成。Android 构建将自动读取 brand.properties。');
}

Map<String, String> _parseProperties(String raw) {
  final map = <String, String>{};
  for (final line in raw.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final i = t.indexOf('=');
    if (i <= 0) continue;
    final k = t.substring(0, i).trim();
    final v = t.substring(i + 1).trim();
    map[k] = v;
  }
  return map;
}

String? _readExistingIosBundleId(File appBrandPath) {
  if (!appBrandPath.existsSync()) return null;
  final m = RegExp(r"iosBundleId\s*=\s*'([^']*)'")
      .firstMatch(appBrandPath.readAsStringSync());
  return m?.group(1);
}

void _writeAppBrand(
  File path, {
  required String applicationId,
  required String iosBundleId,
  required String getuiAppId,
  required String channelId,
  required String shorebirdAppId,
}) {
  final buf = StringBuffer()
    ..writeln('// 由 tool/sync_brand.dart 根据 brand.properties 生成，请勿手改。')
    ..writeln('// 修改品牌信息请编辑项目根目录 brand.properties 后执行: dart run tool/sync_brand.dart')
    ..writeln()
    ..writeln('class AppBrand {')
    ..writeln('  AppBrand._();')
    ..writeln()
    ..writeln('  /// Android applicationId，与 Gradle 中一致')
    ..writeln("  static const String applicationId = '${_esc(applicationId)}';")
    ..writeln()
    ..writeln('  /// iOS Bundle ID（与 Xcode 中 PRODUCT_BUNDLE_IDENTIFIER 一致）')
    ..writeln("  static const String iosBundleId = '${_esc(iosBundleId)}';")
    ..writeln()
    ..writeln('  /// 个推 AppId（与 Android manifestPlaceholders 中 GETUI_APPID 一致）')
    ..writeln("  static const String getuiAppId = '${_esc(getuiAppId)}';")
    ..writeln()
    ..writeln('  /// 渠道 ID（分发/统计）')
    ..writeln("  static const String channelId = '${_esc(channelId)}';")
    ..writeln()
    ..writeln('  /// Shorebird app_id（与 shorebird.yaml 一致）')
    ..writeln("  static const String shorebirdAppId =")
    ..writeln("      '${_esc(shorebirdAppId)}';")
    ..writeln('}');
  path.parent.createSync(recursive: true);
  path.writeAsStringSync(buf.toString());
}

String _esc(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
