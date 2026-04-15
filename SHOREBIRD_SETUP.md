# Shorebird 热更新集成指南

## 什么是 Shorebird

Shorebird 是专为 Flutter 设计的代码推送(Code Push)平台,允许在不重新发布到应用商店的情况下,直接向用户推送代码更新。

### 优势
- ✅ **快速修复 Bug**: 无需等待应用商店审核
- ✅ **即时生效**: 用户下次启动应用即可获得更新
- ✅ **官方支持**: 由 Flutter 核心团队成员创建
- ✅ **免费版可用**: 每月 5GB 带宽,1000 次下载

### 限制
- ❌ **不能更新原生代码**: 只能更新 Dart 代码
- ❌ **不能修改权限**: AndroidManifest.xml 等配置文件变更需重新发布
- ❌ **需要网络**: 用户需联网才能下载补丁

---

## 快速开始

### 1. 安装 Shorebird CLI

```bash
# macOS/Linux
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# Windows
# 访问 https://docs.shorebird.dev/guides/install/ 下载安装程序
```

### 2. 登录账号

```bash
# 浏览器登录 (推荐)
shorebird login

# 或使用 CI Token (用于自动化)
shorebird login --ci-token YOUR_TOKEN_HERE
```

获取 CI Token:
1. 访问 https://console.shorebird.dev/
2. 注册/登录账号
3. Account Settings → Create CI Token

### 3. 初始化项目

```bash
cd im-flutter

# 初始化 Shorebird
shorebird init
```

这会创建 `shorebird.yaml` 文件:

```yaml
# 自动生成,包含应用 ID
app_id: your-generated-app-id

# 可选: 配置不同环境
flavors:
  dev:
    app_id: dev-app-id
  prod:
    app_id: prod-app-id
```

### 4. 添加 Flutter 依赖

```bash
# 编辑 pubspec.yaml,添加:
dependencies:
  shorebird_code_push: ^1.1.0

# 安装依赖
flutter pub get
```

---

## 发布流程

### 首次发布基础版本

```bash
# 发布 Android
shorebird release android

# 发布 iOS (需要 macOS + Xcode)
shorebird release ios

# 发布特定环境
shorebird release android --flavor dev --dart-define=ENV=dev
```

**重要**:
- 首次发布会生成 APK/IPA 文件
- 记录版本号 (如: 0.6.8+1)
- 将 APK 分发给用户 (应用商店/直接下载)

### 推送热更新补丁

```bash
# 1. 修改 Dart 代码 (Bug 修复、UI 调整等)

# 2. 推送补丁到最新版本
shorebird patch android

# 3. 推送到指定版本
shorebird patch android --release-version=0.6.8+1

# 4. 推送到特定环境
shorebird patch android --flavor dev
```

**什么可以更新**:
- ✅ UI 布局和样式
- ✅ 业务逻辑代码
- ✅ 第三方包的 Dart 代码

**什么不能更新**:
- ❌ 原生插件代码
- ❌ AndroidManifest.xml / Info.plist
- ❌ 新增权限或资源

### 查看发布历史

```bash
# 列出所有发布版本
shorebird releases list

# 查看特定版本的补丁
shorebird patches list --release-version=0.6.8+1

# 查看补丁详情
shorebird patch view <patch-number>
```

---

## 客户端集成

### 基础示例

```dart
import 'package:shorebird_code_push/shorebird_code_push.dart';

class UpdateManager {
  final _codePush = ShorebirdCodePush();

  // 检查是否有更新
  Future<bool> checkForUpdate() async {
    return await _codePush.isNewPatchAvailableForDownload();
  }

  // 下载更新
  Future<void> downloadUpdate() async {
    await _codePush.downloadUpdateIfAvailable();
  }

  // 获取当前补丁版本
  Future<int?> getCurrentPatch() async {
    return await _codePush.currentPatchNumber();
  }
}
```

### 应用启动时检查更新

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());

  // 延迟检查,避免影响启动速度
  Future.delayed(Duration(seconds: 3), () async {
    final codePush = ShorebirdCodePush();
    final hasUpdate = await codePush.isNewPatchAvailableForDownload();

    if (hasUpdate) {
      // 静默下载
      await codePush.downloadUpdateIfAvailable();
      // 下次启动时自动应用
    }
  });
}
```

### 带 UI 提示的更新

```dart
Future<void> checkAndUpdateWithUI(BuildContext context) async {
  final codePush = ShorebirdCodePush();
  final hasUpdate = await codePush.isNewPatchAvailableForDownload();

  if (!hasUpdate) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('当前已是最新版本')),
    );
    return;
  }

  // 显示更新对话框
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('发现新版本'),
      content: Text('检测到新版本,是否立即更新?'),
      actions: [
        TextButton(
          child: Text('稍后'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text('立即更新'),
          onPressed: () async {
            Navigator.pop(context);

            // 显示下载进度
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => Center(
                child: CircularProgressIndicator(),
              ),
            );

            await codePush.downloadUpdateIfAvailable();

            Navigator.pop(context);

            // 提示重启
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('更新完成'),
                content: Text('请重启应用以应用更新'),
                actions: [
                  TextButton(
                    child: Text('确定'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}
```

---

## 完整集成示例

详见项目中的 `lib/utils/hot_update_manager.dart` (需要创建)

---

## 本地测试

### 1. 使用预发布渠道

```bash
# 发布到 staging 渠道
shorebird release android --channel staging

# 推送补丁到 staging
shorebird patch android --channel staging
```

客户端指定渠道:

```dart
final codePush = ShorebirdCodePush(channel: 'staging');
```

### 2. 测试流程

```bash
# 1. 发布基础版本
shorebird release android --channel dev

# 2. 安装到设备
# 在 build/ 目录找到 APK

# 3. 修改代码 (如: 改变按钮文字)

# 4. 推送补丁
shorebird patch android --channel dev

# 5. 重启应用查看效果
```

---

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: Shorebird Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'

      - name: Setup Shorebird
        run: |
          curl --proto '=https' --tlsv1.2 \
            https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh \
            -sSf | bash
          echo "$HOME/.shorebird/bin" >> $GITHUB_PATH

      - name: Login to Shorebird
        run: shorebird login --ci-token ${{ secrets.SHOREBIRD_TOKEN }}

      - name: Release
        run: shorebird release android

      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

---

## 最佳实践

### 1. 版本管理

- **完整发布** (应用商店): 每 2-4 周,包含新功能
- **热更新补丁**: 随时,用于 Bug 修复
- **紧急补丁**: 24 小时内,修复严重问题

### 2. 更新策略

**静默更新** (推荐):
```dart
// 后台下载,下次启动生效
Future.delayed(Duration(seconds: 5), () {
  ShorebirdCodePush().downloadUpdateIfAvailable();
});
```

**提示更新**:
```dart
// 用户确认后下载
if (await hasUpdate()) {
  showUpdateDialog();
}
```

**强制更新** (谨慎使用):
```dart
// 阻塞式更新
await downloadUpdate();
exit(0); // 重启应用
```

### 3. 监控和日志

```dart
final patchNumber = await ShorebirdCodePush().currentPatchNumber();

// 记录到分析平台
analytics.logEvent('app_version', {
  'patch': patchNumber,
  'version': packageInfo.version,
});
```

### 4. 回滚策略

如果补丁有问题:

```bash
# 方式1: 推送修复后的代码作为新补丁
shorebird patch android

# 方式2: 在 Console 禁用有问题的补丁
# https://console.shorebird.dev/ → 选择版本 → Disable Patch
```

---

## 常见问题

### Q: 更新何时生效?

补丁下载完成后,**下次启动应用**时生效,不会在运行时立即应用。

### Q: 用户必须联网吗?

是的,需要联网下载补丁。离线用户会在下次联网时自动下载。

### Q: 免费版够用吗?

免费版每月:
- 5GB 带宽
- 1000 次补丁下载

对于小型应用足够,超出后可升级到付费版 ($20/月起)。

### Q: iOS 如何重启应用?

iOS 不允许程序化重启,只能提示用户手动关闭并重新打开应用。

### Q: 如何回滚?

1. 在 Shorebird Console 禁用有问题的补丁
2. 或推送旧版本代码作为新补丁

### Q: 能否 A/B 测试?

可以使用不同的 channel:

```bash
shorebird patch android --channel beta  # 10% 用户
shorebird patch android --channel prod  # 90% 用户
```

---

## 相关资源

- [Shorebird 官方文档](https://docs.shorebird.dev/)
- [Shorebird Console](https://console.shorebird.dev/)
- [Discord 社区](https://discord.gg/shorebird)
- [示例代码](https://github.com/shorebirdtech/samples)

---

## 下一步

1. ✅ 安装 Shorebird CLI
2. ✅ 登录账号
3. ✅ 初始化项目 (`shorebird init`)
4. ⬜ 发布基础版本 (`shorebird release android`)
5. ⬜ 集成客户端代码
6. ⬜ 测试热更新流程
