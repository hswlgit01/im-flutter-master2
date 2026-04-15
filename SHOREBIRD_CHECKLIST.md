# Shorebird 集成检查清单

## 前置准备

- [ ] 访问 https://console.shorebird.dev/ 注册账号
- [ ] 了解 Shorebird 的限制(只能更新 Dart 代码,不能更新原生代码)
- [ ] 确认网络可以访问 Shorebird 服务

## 安装配置

- [ ] 安装 Shorebird CLI
  ```bash
  curl --proto '=https' --tlsv1.2 \
    https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh \
    -sSf | bash
  ```

- [ ] 登录 Shorebird 账号
  ```bash
  shorebird login
  ```

- [ ] 初始化项目
  ```bash
  cd im-flutter
  shorebird init
  ```

- [ ] 添加 Flutter 依赖到 `pubspec.yaml`
  ```yaml
  dependencies:
    shorebird_code_push: ^1.1.0
  ```

- [ ] 安装依赖
  ```bash
  flutter pub get
  ```

## 代码集成

- [ ] 在 `lib/main.dart` 中导入热更新管理器
  ```dart
  import 'utils/hot_update_manager.dart';
  ```

- [ ] 在 `main()` 函数中添加启动检查
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    runApp(MyApp());

    // 延迟检查更新
    Future.delayed(Duration(seconds: 3), () {
      HotUpdateManager().checkUpdateOnStartup();
    });
  }
  ```

- [ ] (可选) 在设置页面添加手动检查更新按钮
  ```dart
  import 'package:openim/utils/hot_update_manager.dart';

  // 在设置页面
  ElevatedButton(
    onPressed: () => HotUpdateManager().manualCheckUpdate(context),
    child: Text('检查更新'),
  )
  ```

- [ ] (可选) 在关于页面显示补丁版本号
  ```dart
  FutureBuilder<String>(
    future: HotUpdateManager().getVersionInfo(packageInfo.version),
    builder: (context, snapshot) {
      return Text('版本: ${snapshot.data ?? packageInfo.version}');
    },
  )
  ```

## 首次发布

- [ ] 发布基础版本
  ```bash
  shorebird release android
  ```

- [ ] 记录版本信息
  - 版本号: `____________________`
  - 构建号: `____________________`
  - 发布时间: `____________________`

- [ ] 测试 APK
  - [ ] 安装到测试设备
  - [ ] 检查应用正常运行
  - [ ] 检查热更新功能是否启用

## 热更新测试

- [ ] 修改测试代码 (如: 改变按钮文字、颜色)

- [ ] 推送补丁
  ```bash
  shorebird patch android
  ```

- [ ] 测试更新流程
  - [ ] 打开应用,等待3秒
  - [ ] 查看日志,确认检测到更新
  - [ ] 查看日志,确认补丁下载完成
  - [ ] 重启应用
  - [ ] 验证修改是否生效

## 版本管理

- [ ] 设置版本命名规范
  - 主版本.次版本.修订版+构建号
  - 例如: 0.6.8+1

- [ ] 制定发布策略
  - [ ] 完整发布周期: `______ 周`
  - [ ] 热更新使用场景: Bug修复、小优化
  - [ ] 紧急补丁响应时间: `______ 小时`

## 监控和日志

- [ ] 集成分析平台记录补丁应用情况
  ```dart
  final patch = await HotUpdateManager().getCurrentPatchNumber();
  analytics.logEvent('patch_applied', {'patch': patch});
  ```

- [ ] 设置错误追踪
  ```dart
  try {
    await codePush.downloadUpdateIfAvailable();
  } catch (e) {
    crashlytics.recordError(e, StackTrace.current);
  }
  ```

## CI/CD 集成 (可选)

- [ ] 在 CI/CD 中添加 Shorebird Token
  - GitHub: Secrets → SHOREBIRD_TOKEN
  - GitLab: Settings → CI/CD → Variables

- [ ] 创建自动发布工作流
  - [ ] 自动发布 release
  - [ ] 自动推送 patch

## 文档和培训

- [ ] 团队成员阅读 `SHOREBIRD_SETUP.md`
- [ ] 了解什么可以热更新,什么不能
- [ ] 了解回滚流程
- [ ] 了解紧急发布流程

## 应急预案

- [ ] 制定补丁回滚流程
  1. 在 Console 禁用有问题的补丁
  2. 或推送修复补丁

- [ ] 准备完整版本发布备选方案
  - 如果热更新失败,准备完整 APK 发布

## 验收标准

- [ ] 应用启动时能自动检查更新
- [ ] 检测到更新后能静默下载
- [ ] 重启应用后更新生效
- [ ] 手动检查更新功能正常
- [ ] 无更新时提示"已是最新版本"
- [ ] 更新失败时有错误提示
- [ ] 版本信息显示正确 (包含补丁号)

## 上线检查

- [ ] 在测试环境完整测试整个流程
- [ ] 在少量设备上灰度测试
- [ ] 监控更新成功率和错误日志
- [ ] 准备好紧急回滚方案
- [ ] 全量发布

## 常见问题排查

### 问题: shorebird command not found
- [ ] 检查是否安装成功
- [ ] 添加到 PATH: `export PATH="$HOME/.shorebird/bin:$PATH"`

### 问题: 登录失败
- [ ] 检查网络连接
- [ ] 尝试使用 CI Token: `shorebird login --ci-token TOKEN`

### 问题: 发布失败
- [ ] 检查 shorebird.yaml 是否存在
- [ ] 确认已登录: `shorebird account`
- [ ] 查看详细错误: `shorebird release android --verbose`

### 问题: 应用检测不到更新
- [ ] 确认使用 shorebird 发布的 APK
- [ ] 检查代码中是否正确集成
- [ ] 查看应用日志中的 [HotUpdate] 输出
- [ ] 确认设备有网络连接

### 问题: 更新下载失败
- [ ] 检查网络连接
- [ ] 检查防火墙/代理设置
- [ ] 查看错误日志

## 相关链接

- Shorebird Console: https://console.shorebird.dev/
- 官方文档: https://docs.shorebird.dev/
- Discord 社区: https://discord.gg/shorebird
- 项目文档: ./SHOREBIRD_SETUP.md

---

**检查清单完成日期**: __________

**负责人**: __________

**验收人**: __________
