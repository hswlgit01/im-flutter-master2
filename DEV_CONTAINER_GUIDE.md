# 开发容器使用指南

## 进入开发容器

```bash
./docker-build.sh dev
```

执行后会看到欢迎界面:

```
================================
✓ 已进入 Flutter 开发容器
================================

✓ Shorebird 已登录
✓ Shorebird 项目已初始化

快捷命令:
  sb               → 显示 Shorebird 帮助
  sb login         → 登录 Shorebird
  sb init          → 初始化项目
  sb release [env] → 发布基础版本
  sb patch [env]   → 推送热更新
  sb list          → 查看发布历史

Flutter 命令:
  flutter build apk --dart-define=ENV=dev  → 构建 APK
  flutter pub get                         → 安装依赖
  flutter clean                           → 清理缓存

当前工作目录: /app
Flutter 版本: Flutter 3.24.5
Shorebird 版本: 1.x.x

================================

[Flutter] /app$
```

---

## 使用 Shorebird (容器内)

### 方式 1: 使用快捷命令 `sb` (推荐)

```bash
# 查看帮助
sb

# 登录
sb login

# 初始化项目
sb init

# 发布基础版本
sb release          # 开发环境
sb release prod     # 生产环境

# 推送热更新
sb patch            # 开发环境
sb patch prod       # 生产环境

# 查看发布历史
sb list

# 查看账号信息
sb account
```

### 方式 2: 使用辅助脚本

```bash
./shorebird-helper.sh login
./shorebird-helper.sh init
./shorebird-helper.sh release dev
./shorebird-helper.sh patch prod
./shorebird-helper.sh list
```

### 方式 3: 直接使用 shorebird 命令

```bash
# 登录
shorebird login

# 初始化
shorebird init

# 发布
shorebird release android --dart-define=ENV=dev

# 推送补丁
shorebird patch android --dart-define=ENV=prod

# 查看历史
shorebird releases list
shorebird patches list --release-version=0.6.8+1

# 查看账号
shorebird account

# 环境检查
shorebird doctor
```

---

## 完整工作流程示例

### 场景 1: 首次设置

```bash
# 1. 进入容器
./docker-build.sh dev

# 2. 登录 Shorebird (容器内)
sb login
# 选择浏览器登录

# 3. 初始化项目
sb init

# 4. 发布基础版本
sb release dev

# 5. 退出容器
exit
```

### 场景 2: 日常开发

```bash
# 1. 进入容器
./docker-build.sh dev

# 2. 安装依赖
flutter pub get

# 3. 修改代码...

# 4. 构建 APK 测试
flutter build apk --dart-define=ENV=dev

# 5. 或直接发布 (使用 Shorebird)
sb release dev

# 6. 退出
exit
```

### 场景 3: 推送热更新

```bash
# 1. 进入容器
./docker-build.sh dev

# 2. 修改代码...

# 3. 推送补丁
sb patch dev
# 或指定版本: 选择 y，输入版本号

# 4. 查看结果
sb list

# 5. 退出
exit
```

### 场景 4: 查看发布历史

```bash
# 1. 进入容器
./docker-build.sh dev

# 2. 查看所有发布
sb list

# 输出:
# === 发布列表 ===
# 0.6.8+1  2024-12-21  (3 patches)
#
# 查看某版本的补丁? [y/N]: y
# 版本号: 0.6.8+1
#
# === 补丁列表 (0.6.8+1) ===
# Patch 3  2024-12-21 14:30
# Patch 2  2024-12-21 10:15
# Patch 1  2024-12-21 09:00

# 3. 退出
exit
```

---

## 容器内可用别名

在容器内自动配置了以下别名:

| 别名 | 等同于 | 说明 |
|------|--------|------|
| `sb` | `./shorebird-helper.sh` | Shorebird 快捷命令 |
| `flutter-build` | `flutter build apk --release --dart-define=ENV=dev` | 快速构建 APK |
| `flutter-clean` | `flutter clean && flutter pub get` | 清理并重装依赖 |
| `shorebird-status` | `shorebird account` | 查看 Shorebird 状态 |

示例:
```bash
# 快速构建
flutter-build

# 清理缓存
flutter-clean

# 查看状态
shorebird-status
```

---

## 环境变量说明

容器内已配置以下环境变量:

```bash
FLUTTER_HOME=/opt/flutter
ANDROID_HOME=/opt/android
ANDROID_SDK_ROOT=/opt/android
SHOREBIRD_HOME=/root/.shorebird
```

所有工具都已添加到 PATH,可直接使用:
- `flutter`
- `dart`
- `shorebird`
- `sdkmanager`
- `gradle`

---

## 文件映射

容器内的 `/app` 目录映射到宿主机的 `im-flutter/`:

| 容器内 | 宿主机 |
|--------|--------|
| `/app/lib/` | `im-flutter/lib/` |
| `/app/build/` | `im-flutter/build/` |
| `/app/shorebird.yaml` | `im-flutter/shorebird.yaml` |
| `/app/pubspec.yaml` | `im-flutter/pubspec.yaml` |

在容器内修改的文件,宿主机也会同步更新。

---

## 持久化数据

以下数据通过 Docker 卷持久化,容器重启不会丢失:

- **flutter_cache**: Flutter pub 缓存 (`/root/.pub-cache`)
- **gradle_cache**: Gradle 构建缓存 (`/root/.gradle`)
- **shorebird_cache**: Shorebird 凭证和配置 (`/root/.shorebird`)

**好处**:
- ✅ 登录一次,永久有效
- ✅ 依赖下载一次,后续无需重复
- ✅ 构建速度更快

---

## 常见操作

### 检查 Shorebird 登录状态

```bash
# 方式1: 使用别名
shorebird-status

# 方式2: 使用命令
shorebird account

# 方式3: 检查文件
ls -la /root/.shorebird/credentials.json
```

### 重新登录

```bash
sb login
```

### 查看所有 Shorebird 命令

```bash
shorebird --help
```

### 构建不同环境的 APK

```bash
# 开发环境
flutter build apk --dart-define=ENV=dev

# 测试环境
flutter build apk --dart-define=ENV=test

# 生产环境
flutter build apk --dart-define=ENV=prod
```

### 使用 Shorebird 发布不同环境

```bash
# 开发环境
sb release dev

# 测试环境
sb release test

# 生产环境
sb release prod
```

---

## 故障排查

### 问题: 进入容器后没有显示欢迎界面

**原因**: `.bashrc_docker` 文件可能不存在或没有执行权限

**解决**:
```bash
# 在容器内手动加载
source /app/.bashrc_docker

# 或退出重新进入
exit
./docker-build.sh dev
```

### 问题: `sb` 命令不存在

**原因**: 别名未加载

**解决**:
```bash
# 手动创建别名
alias sb='./shorebird-helper.sh'

# 或直接使用完整路径
./shorebird-helper.sh login
```

### 问题: Shorebird 显示未登录

**解决**:
```bash
# 重新登录
sb login

# 或使用 CI Token
shorebird login --ci-token YOUR_TOKEN
```

### 问题: 容器内文件权限错误

**原因**: 容器内是 root 用户,创建的文件可能有权限问题

**解决**:
```bash
# 在宿主机修复权限
sudo chown -R $USER:$USER .
```

---

## 与宿主机命令对比

| 操作 | 宿主机 | 容器内 |
|------|--------|--------|
| 登录 Shorebird | `./docker-build.sh shorebird-login` | `sb login` |
| 初始化项目 | `./docker-build.sh shorebird-init` | `sb init` |
| 发布版本 | `./docker-build.sh shorebird-release dev` | `sb release dev` |
| 推送补丁 | `./docker-build.sh shorebird-patch prod` | `sb patch prod` |
| 查看历史 | `./docker-build.sh shorebird-list` | `sb list` |
| 进入 shell | `./docker-build.sh shorebird-shell` | (已在容器内) |

**选择建议**:
- **宿主机命令**: 适合快速一次性操作
- **容器内命令**: 适合需要多次操作、调试、或执行复杂命令

---

## 高级用法

### 执行一次性命令(不进入容器)

```bash
# 在宿主机执行单个命令
docker compose run --rm flutter shorebird releases list

# 执行多个命令
docker compose run --rm flutter bash -c "
  shorebird releases list
  shorebird account
"
```

### 后台运行容器

```bash
# 启动但不进入
docker compose up -d flutter

# 稍后进入
docker compose exec flutter bash

# 停止
docker compose stop flutter
```

### 查看容器日志

```bash
docker compose logs flutter
```

---

## 下一步

1. ✅ 阅读本文档
2. ⬜ 执行 `./docker-build.sh dev` 进入容器
3. ⬜ 在容器内执行 `sb login` 登录
4. ⬜ 执行 `sb init` 初始化项目
5. ⬜ 尝试 `sb release dev` 发布版本
6. ⬜ 修改代码并执行 `sb patch dev` 测试热更新

---

**需要帮助?**
- 在容器内执行 `sb` 查看快捷命令
- 查看 [DOCKER_SHOREBIRD_GUIDE.md](./DOCKER_SHOREBIRD_GUIDE.md) 了解更多
- 查看 [SHOREBIRD_SETUP.md](./SHOREBIRD_SETUP.md) 了解 Shorebird 详细用法
