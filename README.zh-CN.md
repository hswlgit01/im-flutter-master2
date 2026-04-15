
## 开发环境

在开始开发之前，请确保您的系统已安装以下软件：

- **操作系统**：macOS 14.6 或更高版本
- **Flutter**：版本 3.24.5（根据官网步骤进行[安装](https://docs.flutter.cn/get-started/install)）XCode: 15.4, Android Studio: Koala | 2024.1.1 Patch 1
- **OpenJDK**: 17
- **gradle**: 7.6.3
- **Android commandlinetools**: 10406996_latest

## 运行环境

本应用支持以下操作系统版本：

| 操作系统 | 版本              | 状态 |
| --------------- | ----------------- | ---- |
| **iOS**      | 13.0 及以上         | ✅   |
| **Android**     | minSdkVersion 24 | ✅   |

### 说明

- **Flutter**：确保您的版本符合要求，以避免依赖问题。

## 快速开始

按照以下步骤设置本地开发环境：

1. 拉取代码


2. 安装依赖

```bash
  flutter clean 
  flutter pub get
```

3. 配置服务器地址

  本应用支持三种环境配置：开发环境（dev）、测试环境（test）、生产环境（prod）。

  #### 方式一：配置固定服务器地址（推荐用于本地开发）

  编辑 `openim_common/lib/src/config.dart` 文件：

  ```dart
  class Config {
    // 定义不同环境的主机地址
    static const String _devHost = "192.168.31.166";  // 本地开发环境
    static const String _testHost = "";                 // 测试环境（留空则启用自动寻路）
    static const String _prodHost = "";                 // 生产环境（留空则启用自动寻路）

    // 设置默认环境
    static final String _currentEnv = const String.fromEnvironment('ENV', defaultValue: 'dev');
  }
  ```

  #### 服务器地址规则

  当配置的是 **IP 地址**（如 `192.168.31.166`）时，系统会自动生成以下地址：
  ```
  API地址:      http://192.168.31.166:10002
  WebSocket:    ws://192.168.31.166:10001
  认证地址:      http://192.168.31.166:10008
  Chat Token:   http://192.168.31.166:10009
  ```

  当配置的是 **域名**（如 `example.com`）时，系统会自动生成以下地址：
  ```
  API地址:      https://example.com/api
  WebSocket:    wss://example.com/msg_gateway
  认证地址:      https://example.com/chat
  Chat Token:   https://example.com/chat
  ```

  #### 方式二：自动寻路（推荐用于测试/生产环境）

  如果将环境主机地址留空（如上面的 `_testHost` 和 `_prodHost`），应用会在启动时自动寻找最快的服务器。

  详见 `openim_common/lib/src/utils/api_auto_route.dart` 配置。

4. 通过终端执行 `flutter run` 或者IDE的启动菜单来运行iOS/Android应用程序。

5. 开始开发测试！ 🎉

## 音视频通话

支持一对一音视频通话，并且需要先部署并配置[服务端]

## 构建 🚀

> 该项目允许分别构建 iOS 应用程序和 Android 应用程序，但在构建过程中会有一些差异。

   - iOS:
     ```bash
     flutter build ipa
     ```
   - Android:
     ```bash
     flutter build apk
     ```

 构建结果将位于 `build`  目录下。

## 功能列表

### 说明

| 功能模块           | 功能项                                                    | 状态 |
| ------------------ | --------------------------------------------------------- | ---- |
| **账号功能**       | 手机号注册\邮箱注册\验证码登录                            | ✅   |
|                    | 个人信息查看\修改                                         | ✅   |
|                    | 多语言设置                                                | ✅   |
|                    | 修改密码\忘记密码                                         | ✅   |
| **好友功能**       | 查找\申请\搜索\添加\删除好友                              | ✅   |
|                    | 同意\拒绝好友申请                                         | ✅   |
|                    | 好友备注                                                  | ✅   |
|                    | 是否允许添加好友                                          | ✅   |
|                    | 好友列表\好友资料实时同步                                 | ✅   |
| **黑名单功能**     | 限制消息                                                  | ✅   |
|                    | 黑名单列表实时同步                                        | ✅   |
|                    | 添加\移出黑名单                                           | ✅   |
| **群组功能**       | 创建\解散群组                                             | ✅   |
|                    | 申请加群\邀请加群\退出群组\移除群成员                     | ✅   |
|                    | 群名/群头像更改/群资料变更通知和实时同步                  | ✅   |
|                    | 群成员邀请进群                                            | ✅   |
|                    | 群主转让                                                  | ✅   |
|                    | 群主、管理员同意进群申请                                  | ✅   |
|                    | 搜索群成员                                                | ✅   |
| **消息功能**       | 离线消息                                                  | ✅   |
|                    | 漫游消息                                                  | ✅   |
|                    | 多端消息                                                  | ✅   |
|                    | 历史消息                                                  | ✅   |
|                    | 消息删除                                                  | ✅   |
|                    | 消息清空                                                  | ✅   |
|                    | 消息复制                                                  | ✅   |
|                    | 单聊正在输入                                              | ✅   |
|                    | 新消息勿扰                                                | ✅   |
|                    | 清空聊天记录                                              | ✅   |
|                    | 新成员查看群聊历史消息                                    | ✅   |
|                    | 新消息提示                                                | ✅   |
|                    | 文本消息                                                  | ✅   |
|                    | 图片消息                                                  | ✅   |
|                    | 视频消息                                                  | ✅   |
|                    | 表情消息                                                  | ✅   |
|                    | 文件消息                                                  | ✅   |
|                    | 语音消息                                                  | ✅   |
|                    | 名片消息                                                  | ✅   |
|                    | 地理位置消息                                              | ✅   |
|                    | 自定义消息                                                | ✅   |
| **会话功能**       | 置顶会话                                                  | ✅   |
|                    | 会话已读                                                  | ✅   |
|                    | 会话免打扰                                                | ✅   |
| **REST API**       | 认证管理                                                  | ✅   |
|                    | 用户管理                                                  | ✅   |
|                    | 关系链管理                                                | ✅   |
|                    | 群组管理                                                  | ✅   |
|                    | 会话管理                                                  | ✅   |
|                    | 消息管理                                                  | ✅   |
| **Webhook**        | 群组回调                                                  | ✅   |
|                    | 消息回调                                                  | ✅   |
|                    | 推送回调                                                  | ✅   |
|                    | 关系链回调                                                | ✅   |
|                    | 用户回调                                                  | ✅   |
| **容量和性能**     | 1 万好友                                                  | ✅   |
|                    | 10 万人大群                                               | ✅   |
|                    | 秒级同步                                                  | ✅   |
|                    | 集群部署                                                  | ✅   |
|                    | 互踢策略                                                  |      |
| **在线状态**       | 所有平台不互踢                                            | ✅   |
|                    | 每个平台各只能登录一个设备                                | ✅   |
|                    | PC 端、移动端、Pad 端、Web 端、小程序端各只能登录一个设备 | ✅   |
|                    | PC 端不互踢，其他平台总计一个设备                         | ✅   |
| **音视频通话**     | 一对一音视频通话                                          | ✅   |
| **文件类对象存储** | 支持私有化部署 minio                                      | ✅   |
|                    | 支持 COS、OSS、Kodo、S3 公有云                            | ✅   |
| **推送**           | 消息在线实时推送                                          | ✅   |
|                    | 消息离线推送，支持个推，Firebase                          | ✅   |


## 常见问题

##### 1. 是否支持多语言？
答：支持，默认跟随系统语言。

##### 2. 支持哪些平台？
答：目前 Demo 支持 Android 和 iOS。

##### 3. Android 安装包的 debug 版本可以运行，但 release 启动是白屏？
答：Flutter 的 release 包默认会进行混淆，可以使用以下命令：

```bash
  flutter build release --no-shrink
```

如果此命令无效，可以在 android/app/build.gradle 文件的 release 配置中添加以下代码：

```bash
  release {
      minifyEnabled false
      useProguard false
      shrinkResources false
  }
```

##### 4. 如果代码必须混淆该怎么办？
答：在混淆规则中添加以下配置：

```bash
  -keep class io.FREECHAT.**{*;}
  -keep class open_im_sdk.**{*;}
  -keep class open_im_sdk_callback.**{*;}
```

##### 5. Android 安装包无法安装在模拟器上？
答：由于 Demo 移除了一些 CPU 架构，如果需要在模拟器上运行，请在 android/build.gradle 配置中添加以下内容：

```bash
  ndk {
      abiFilters "armeabi-v7a",  "x86"
  }
```

##### 6. iOS 运行/打包 release 包时报错？
答：请将 CPU 架构设置为 arm64，然后按以下步骤操作：

```bash
  执行 flutter clean
  执行 flutter pub get
  cd ios/
  rm -f Podfile.lock
  rm -rf Pods
  执行 pod install
  连接真机后运行 Archive。
```
![ios cpu](https://user-images.githubusercontent.com/7018230/155913400-6231329a-aee9-4082-8d24-a25baad55261.png)

##### 7. iOS 最低运行版本是多少？

答：13.0

##### 8. 地图为什么不能使用？

答: [文档](CONFIGKEY.zh-CN.md)

##### 9. 离线推送为什么不能使用？

答: [文档](CONFIGKEY.zh-CN.md)




# 查看可用的模拟器
flutter emulators


# 启动 Android 模拟器
flutter emulators --launch Medium_Phone_API_35


flutter run

flutter build apk      
// 打包aab文件
flutter build appbundle --release   

ios

# 列出可用的模拟器
xcrun simctl list devices


直接从 Xcode 打开模拟器
open -a Simulator

# 使用 iPhone 15 的设备 ID 启动
xcrun simctl boot B9686AFC-C95D-43FE-978B-B06217A73F8A

# 指定运行在 iOS 设备上
flutter run -d B9686AFC-C95D-43FE-978B-B06217A73F8A

flutter run -d iphone

按 r 键：执行热重载（Hot Reload），保持应用状态
按 R 键：执行热重启（Hot Restart），重置应用状态
按 h 键：显示所有可用的命令

# 查看所有可用设备
flutter devices

# 清理项目
flutter clean

# 获取依赖
flutter pub get

#修改完 logo 后，我们需要运行特定的命令来生成新的图标文件
flutter pub get && flutter pub run flutter_launcher_icons



## 环境切换

### 运行不同环境

应用支持通过 `--dart-define=ENV` 参数指定运行环境：

```bash
# 开发环境（使用固定服务器地址，不执行自动寻路）
flutter run --dart-define=ENV=dev

# 测试环境（如果配置为空则执行自动寻路）
flutter run --dart-define=ENV=test

# 生产环境（如果配置为空则执行自动寻路）
flutter run --dart-define=ENV=prod
```

### 构建不同环境的发布版本

```bash
# 构建开发环境 APK
flutter build apk --dart-define=ENV=dev

# 构建测试环境 APK
flutter build apk --dart-define=ENV=test

# 构建生产环境 APK
flutter build apk --dart-define=ENV=prod

# 构建 iOS 发布版本
flutter build ipa --dart-define=ENV=prod
```

### 环境配置说明

- **dev（开发环境）**：直接使用 `_devHost` 配置的固定地址，跳过自动寻路，启动速度快
- **test（测试环境）**：如果 `_testHost` 为空，则执行自动寻路选择最快服务器
- **prod（生产环境）**：如果 `_prodHost` 为空，则执行自动寻路选择最快服务器

### 默认环境设置

在 `openim_common/lib/src/config.dart` 中修改默认环境：

```dart
// 默认使用开发环境
static final String _currentEnv = const String.fromEnvironment('ENV', defaultValue: 'dev');

// 如果不指定 --dart-define=ENV 参数，应用将使用此默认环境
```

# 把最新的 Flutter 代码编译到 ios 目录下
flutter build ios --release