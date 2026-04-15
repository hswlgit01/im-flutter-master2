# Docker + Shorebird 集成使用指南

## 概述

Shorebird 已完全集成到 Docker 构建环境中,所有 Shorebird 操作都可以通过 `docker-build.sh` 脚本完成。

---

## 快速开始

### 1. 登录 Shorebird

```bash
./docker-build.sh shorebird-login
```

选择登录方式:
- **浏览器登录** (推荐): 自动打开浏览器完成登录
- **CI Token**: 适用于自动化/CI环境

### 2. 初始化项目

```bash
./docker-build.sh shorebird-init
```

这会创建 `shorebird.yaml` 文件并配置应用ID。

### 3. 首次发布

```bash
# 发布开发环境版本
./docker-build.sh shorebird-release dev

# 发布生产环境版本
./docker-build.sh shorebird-release prod
```

**重要**: 记录发布的版本号(如: 0.6.8+1),后续推送补丁时需要。

### 4. 推送热更新补丁

```bash
# 修改代码后,推送补丁到开发环境
./docker-build.sh shorebird-patch dev

# 推送到生产环境
./docker-build.sh shorebird-patch prod
```

---

## 完整命令列表

### Shorebird 命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `shorebird-login` | 登录 Shorebird 账号 | `./docker-build.sh shorebird-login` |
| `shorebird-init` | 初始化项目 | `./docker-build.sh shorebird-init` |
| `shorebird-release [env]` | 发布基础版本 | `./docker-build.sh shorebird-release prod` |
| `shorebird-patch [env]` | 推送热更新补丁 | `./docker-build.sh shorebird-patch dev` |
| `shorebird-list` | 查看发布历史 | `./docker-build.sh shorebird-list` |
| `shorebird-shell` | 进入 Shorebird shell | `./docker-build.sh shorebird-shell` |

### 传统 Flutter 命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `apk [env]` | 构建普通 APK | `./docker-build.sh apk prod` |
| `web [env]` | 构建 Web 应用 | `./docker-build.sh web` |
| `dev` | 启动开发容器 | `./docker-build.sh dev` |
| `clean` | 清理缓存 | `./docker-build.sh clean` |

---

## 两种使用方式

### 方式 1: 宿主机命令 (快速操作)

适合一次性操作,无需进入容器:

```bash
./docker-build.sh shorebird-login
./docker-build.sh shorebird-release dev
./docker-build.sh shorebird-patch dev
```

### 方式 2: 容器内命令 (开发调试)

适合需要多次操作、调试或复杂命令:

```bash
# 1. 进入容器
./docker-build.sh dev

# 2. 在容器内使用简化命令
sb login            # 等同于 shorebird login
sb release dev      # 等同于 shorebird release android --dart-define=ENV=dev
sb patch prod       # 等同于 shorebird patch android --dart-define=ENV=prod
sb list             # 等同于 shorebird releases list

# 3. 退出容器
exit
```

**详细的容器内使用指南**: 查看 [DEV_CONTAINER_GUIDE.md](./DEV_CONTAINER_GUIDE.md)

---

## 使用流程

### 场景 1: 首次集成 Shorebird

```bash
# 1. 登录
./docker-build.sh shorebird-login

# 2. 初始化项目
./docker-build.sh shorebird-init

# 3. 发布基础版本
./docker-build.sh shorebird-release dev

# 4. 分发 APK 给测试用户
# APK 位于: build/app/outputs/flutter-apk/
```

### 场景 2: 修复线上 Bug

```bash
# 1. 修改代码

# 2. 推送补丁
./docker-build.sh shorebird-patch prod

# 3. 用户下次启动应用时自动下载并应用
```

### 场景 3: 查看发布历史

```bash
./docker-build.sh shorebird-list

# 输出:
# === 发布列表 ===
# 0.6.8+1  2024-12-21  (3 patches)
# 0.6.7+5  2024-12-15  (1 patch)

# 可选: 查看某版本的补丁详情
# 输入版本号: 0.6.8+1
# === 补丁列表 (0.6.8+1) ===
# Patch 3  2024-12-21 14:30
# Patch 2  2024-12-21 10:15
# Patch 1  2024-12-21 09:00
```

### 场景 4: 高级操作 (使用 Shorebird shell)

```bash
./docker-build.sh shorebird-shell

# 进入容器后可执行任意 shorebird 命令:
# shorebird account                          # 查看账号
# shorebird doctor                           # 检查环境
# shorebird releases list                    # 列出发布
# shorebird patches list --release-version=X # 查看补丁
# shorebird patch android --release-version=X --channel staging  # 推送到特定渠道
```

---

## 环境参数

所有构建和发布命令都支持环境参数:

- `dev` - 开发环境 (默认)
- `test` - 测试环境
- `prod` - 生产环境

示例:
```bash
# 发布到不同环境
./docker-build.sh shorebird-release dev   # 开发
./docker-build.sh shorebird-release test  # 测试
./docker-build.sh shorebird-release prod  # 生产

# 推送补丁到不同环境
./docker-build.sh shorebird-patch dev
./docker-build.sh shorebird-patch prod
```

---

## Docker 卷持久化

Shorebird 凭证和缓存已持久化到 Docker 卷:

```yaml
volumes:
  flutter_cache:      # Flutter pub 缓存
  gradle_cache:       # Gradle 构建缓存
  shorebird_cache:    # Shorebird 凭证和配置
```

**好处**:
- ✅ 登录信息保留,无需重复登录
- ✅ 缓存加速构建
- ✅ 容器重建后数据不丢失

**清理** (如需重新登录):
```bash
# 清理所有缓存(包括 Shorebird 凭证)
./docker-build.sh clean

# 或手动删除 Shorebird 卷
docker volume rm im-flutter_shorebird_cache
```

---

## Dockerfile 说明

Shorebird CLI 已集成到 `Dockerfile`:

```dockerfile
# 安装 Shorebird CLI
ENV SHOREBIRD_HOME=/root/.shorebird
ENV PATH=${PATH}:${SHOREBIRD_HOME}/bin
RUN curl --proto '=https' --tlsv1.2 \
    https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh \
    -sSf | bash && \
    shorebird --version
```

**特点**:
- ✅ 自动安装最新版 Shorebird
- ✅ 添加到 PATH,可直接使用
- ✅ 与 Flutter、Android SDK 共存

---

## 常见问题

### Q: 如何重新登录?

```bash
# 方式1: 使用登录命令
./docker-build.sh shorebird-login

# 方式2: 进入容器手动登录
./docker-build.sh shorebird-shell
# 然后执行: shorebird login
```

### Q: 如何查看当前登录状态?

```bash
./docker-build.sh shorebird-shell
# 然后执行: shorebird account
```

### Q: 发布失败怎么办?

1. 确认已登录: `./docker-build.sh shorebird-shell` → `shorebird account`
2. 确认已初始化: 检查项目根目录是否有 `shorebird.yaml`
3. 查看详细错误: `./docker-build.sh shorebird-shell` → `shorebird release android --verbose`

### Q: 如何推送补丁到特定版本?

```bash
./docker-build.sh shorebird-patch prod

# 脚本会询问是否指定版本:
# 是否指定目标发布版本? [y/N]: y
# 请输入发布版本号 (如: 0.6.8+1): 0.6.8+1
```

### Q: 容器内外的文件权限问题?

项目目录通过卷挂载 (`- .:/app`),在容器内外都可以访问:
- 容器内: `/app`
- 宿主机: `im-flutter/`

生成的文件(如 `shorebird.yaml`, APK)在两边都可见。

### Q: Shorebird 和普通 Flutter 构建有什么区别?

| 特性 | 普通 Flutter | Shorebird |
|------|-------------|-----------|
| 构建命令 | `flutter build apk` | `shorebird release android` |
| 热更新 | ❌ 不支持 | ✅ 支持 |
| 应用商店 | ✅ 可发布 | ✅ 可发布 |
| 补丁推送 | ❌ 不支持 | ✅ 支持 |

**建议**:
- 首次发布和重大更新: 使用 Shorebird release
- 小 Bug 修复: 使用 Shorebird patch
- 测试构建: 可使用普通 flutter build

---

## 最佳实践

### 1. 版本管理

```bash
# 首次发布
./docker-build.sh shorebird-release prod
# 记录版本: 0.6.8+1

# 后续补丁
./docker-build.sh shorebird-patch prod
# Patch 1, Patch 2, Patch 3...

# 下次重大更新
# 修改 pubspec.yaml 版本号: 0.7.0+1
./docker-build.sh shorebird-release prod
```

### 2. 多环境管理

```bash
# 开发环境: 频繁迭代
./docker-build.sh shorebird-release dev
./docker-build.sh shorebird-patch dev

# 测试环境: 稳定测试
./docker-build.sh shorebird-release test
./docker-build.sh shorebird-patch test

# 生产环境: 正式发布
./docker-build.sh shorebird-release prod
./docker-build.sh shorebird-patch prod
```

### 3. CI/CD 集成

在 CI/CD 环境中使用 CI Token:

```bash
# 设置环境变量
export SHOREBIRD_TOKEN=your_ci_token

# 在容器内使用
docker compose run --rm -e SHOREBIRD_TOKEN flutter bash -c "
  shorebird login --ci-token \$SHOREBIRD_TOKEN
  shorebird release android --dart-define=ENV=prod
"
```

### 4. 团队协作

- 所有团队成员使用相同的 `shorebird.yaml`
- 登录同一个 Shorebird 组织账号
- 发布前沟通,避免冲突

---

## 与其他文档的关系

- **SHOREBIRD_README.md**: 快速入门和概览
- **SHOREBIRD_SETUP.md**: 详细的 Shorebird 使用指南
- **DOCKER_SHOREBIRD_GUIDE.md** (本文档): Docker 环境下的使用
- **lib/utils/hot_update_manager.dart**: 客户端集成代码

---

## 下一步

1. ✅ 阅读本文档
2. ⬜ 执行 `./docker-build.sh shorebird-login` 登录
3. ⬜ 执行 `./docker-build.sh shorebird-init` 初始化
4. ⬜ 执行 `./docker-build.sh shorebird-release dev` 首次发布
5. ⬜ 修改代码,测试热更新: `./docker-build.sh shorebird-patch dev`
6. ⬜ 阅读 [SHOREBIRD_SETUP.md](./SHOREBIRD_SETUP.md) 了解更多细节

---

**需要帮助?** 查看 [Shorebird 官方文档](https://docs.shorebird.dev/) 或使用 `./docker-build.sh shorebird-shell` 进入容器调试。
