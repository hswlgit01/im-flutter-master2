# Shorebird 热更新 - 快速入门

## 📚 文档导航

本项目已完整集成 Shorebird 热更新功能,相关文档如下:

| 文档 | 说明 | 适用人员 |
|------|------|---------|
| **[SHOREBIRD_SETUP.md](./SHOREBIRD_SETUP.md)** | 完整的使用指南和最佳实践 | 所有开发者 |
| **[SHOREBIRD_CHECKLIST.md](./SHOREBIRD_CHECKLIST.md)** | 集成和上线检查清单 | 负责人/测试人员 |
| **lib/utils/hot_update_manager.dart** | 热更新管理器实现代码 | 开发者 |
| **shorebird-quick-start.sh** | 自动化配置脚本 | 新成员 |

---

## ⚡ 快速开始

### 方式 1: 自动化脚本 (推荐)

```bash
cd im-flutter
./shorebird-quick-start.sh
```

脚本会自动完成:
- ✅ 检查并安装 Shorebird CLI
- ✅ 登录账号
- ✅ 初始化项目
- ✅ 添加 Flutter 依赖
- ✅ 提供集成代码示例

### 方式 2: 手动配置

```bash
# 1. 安装 Shorebird CLI
curl --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh \
  -sSf | bash

# 2. 登录
shorebird login

# 3. 初始化项目
cd im-flutter
shorebird init

# 4. 添加依赖
flutter pub add shorebird_code_push

# 5. 集成代码 (见下方)
```

---

## 🔧 代码集成

### 在 lib/main.dart 中添加:

```dart
import 'utils/hot_update_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());

  // 应用启动后自动检查更新
  Future.delayed(Duration(seconds: 3), () {
    HotUpdateManager().checkUpdateOnStartup();
  });
}
```

### 在设置页面添加手动检查更新:

```dart
import 'package:openim/utils/hot_update_manager.dart';

// 方式1: 使用完整的设置组件
HotUpdateSettingWidget()

// 方式2: 自定义按钮
ElevatedButton(
  onPressed: () => HotUpdateManager().manualCheckUpdate(context),
  child: Text('检查更新'),
)
```

---

## 🚀 发布流程

### 首次发布基础版本

```bash
# 发布到生产环境
shorebird release android

# 发布到开发环境
shorebird release android --flavor dev --dart-define=ENV=dev
```

### 推送热更新补丁

```bash
# 1. 修改 Dart 代码 (UI、业务逻辑等)

# 2. 推送补丁
shorebird patch android

# 3. 用户下次启动应用时自动应用更新
```

### 查看历史

```bash
# 查看所有发布版本
shorebird releases list

# 查看补丁列表
shorebird patches list --release-version=0.6.8+1
```

---

## ✅ 能更新什么?

### ✅ 可以热更新:
- Dart 代码 (UI、业务逻辑)
- 第三方包的 Dart 部分
- 资源文件 (但不推荐)

### ❌ 不能热更新:
- 原生代码 (Java/Kotlin/Swift/Objective-C)
- 原生插件的原生部分
- AndroidManifest.xml / Info.plist
- 应用权限变更

---

## 📊 使用场景

### ✅ 适合用热更新:
- 🐛 **Bug 修复**: 快速修复线上问题
- 🎨 **UI 调整**: 界面文字、颜色、布局
- 📝 **文案修改**: 提示语、帮助文档
- 🔧 **配置调整**: API 地址、功能开关

### ❌ 需要完整发布:
- 🆕 **新增功能**: 涉及原生代码或权限
- 🔐 **权限变更**: 需要用户同意
- 📦 **重大重构**: 架构级别的改动
- ⚙️ **引擎升级**: Flutter 版本升级

---

## 🎯 最佳实践

### 1. 发布节奏
- **完整版本**: 每 2-4 周,通过应用商店发布
- **热更新补丁**: 随时,用于 Bug 修复
- **紧急补丁**: 24 小时内,修复严重问题

### 2. 版本命名
```
主版本.次版本.修订版+构建号
例如: 0.6.8+1

- 主版本: 重大架构变更 (1.0.0)
- 次版本: 新功能 (0.8.0)
- 修订版: Bug 修复 (0.7.1)
- 构建号: 每次发布递增 (+1, +2, +3...)
```

### 3. 测试流程
```
1. 本地测试
   ↓
2. 推送到 staging 渠道
   ↓
3. 内部测试 (2-3天)
   ↓
4. 推送到 production
   ↓
5. 监控错误日志
```

### 4. 更新策略

**静默更新** (默认,推荐):
```dart
// 后台下载,下次启动生效,不打扰用户
HotUpdateManager().checkUpdateOnStartup();
```

**手动检查** (设置页面):
```dart
// 用户主动检查
HotUpdateManager().manualCheckUpdate(context);
```

---

## 🔍 常见问题

### Q: 更新什么时候生效?
补丁下载完成后,**下次启动应用**时生效。不会在运行中立即应用。

### Q: 用户需要联网吗?
是的,需要联网下载补丁。离线用户会在下次联网时自动下载。

### Q: 免费版够用吗?
免费版限制:
- 每月 5GB 带宽
- 1000 次补丁下载

对小型应用足够。超出后可升级付费版 ($20/月起)。

### Q: 如何回滚有问题的补丁?
1. 在 [Shorebird Console](https://console.shorebird.dev/) 禁用补丁
2. 或推送修复后的代码作为新补丁

### Q: iOS 支持吗?
支持,但需要 macOS 和 Xcode 环境进行发布。

---

## 📱 使用示例

### 示例 1: 修复线上 Bug

```bash
# 1. 本地修复代码
# 2. 本地测试
flutter run

# 3. 推送补丁
shorebird patch android

# 4. 用户无需手动更新,下次启动自动应用
```

### 示例 2: 调整 UI 文案

```dart
// 修改前
Text('提交')

// 修改后
Text('确认提交')

// 推送补丁
// shorebird patch android
```

### 示例 3: 紧急修复崩溃

```bash
# 1. 修复崩溃代码
# 2. 立即推送
shorebird patch android

# 3. 监控补丁应用率
# 访问 https://console.shorebird.dev/
```

---

## 🛠️ 开发命令

```bash
# 检查 Shorebird 状态
shorebird doctor

# 查看账号信息
shorebird account

# 查看当前项目信息
shorebird apps list

# 预览发布 (不实际发布)
shorebird release android --dry-run

# 发布并查看详细日志
shorebird release android --verbose

# 推送补丁并查看详细日志
shorebird patch android --verbose
```

---

## 📈 监控和分析

### 在代码中记录补丁应用情况:

```dart
import 'package:openim/utils/hot_update_manager.dart';

// 在应用启动时
final patchNumber = await HotUpdateManager().getCurrentPatchNumber();

if (patchNumber != null && patchNumber > 0) {
  // 记录到分析平台
  analytics.logEvent('app_started_with_patch', {
    'patch_number': patchNumber,
    'app_version': packageInfo.version,
  });
}
```

### 在 Shorebird Console 查看:
- 补丁下载次数
- 应用成功率
- 错误日志

访问: https://console.shorebird.dev/

---

## 🔗 相关资源

- **Shorebird 官方文档**: https://docs.shorebird.dev/
- **Shorebird Console**: https://console.shorebird.dev/
- **Discord 社区**: https://discord.gg/shorebird
- **GitHub 示例**: https://github.com/shorebirdtech/samples

---

## 📝 下一步

1. ✅ 阅读完本文档
2. ⬜ 运行快速开始脚本: `./shorebird-quick-start.sh`
3. ⬜ 发布第一个版本: `shorebird release android`
4. ⬜ 测试热更新流程
5. ⬜ 阅读完整文档: [SHOREBIRD_SETUP.md](./SHOREBIRD_SETUP.md)
6. ⬜ 查看检查清单: [SHOREBIRD_CHECKLIST.md](./SHOREBIRD_CHECKLIST.md)

---

**有问题?** 查看详细文档 [SHOREBIRD_SETUP.md](./SHOREBIRD_SETUP.md) 或访问 [Shorebird 官方文档](https://docs.shorebird.dev/)
