# OpenIM Flutter 应用的Docker使用指南

本文档提供了如何使用Docker来开发和构建OpenIM Flutter应用的详细说明。

## 前提条件

- 安装 [Docker](https://www.docker.com/get-started)
- 安装 [Docker Compose](https://docs.docker.com/compose/install/) (Docker Desktop已集成)

## 系统要求

- 至少 8GB 内存
- 至少 20GB 可用磁盘空间
- 良好的网络连接（初次构建需要下载多个大文件）
- Docker 20.10+和Docker Compose v2+
- 容器内环境：Ubuntu 22.04 + Java 17 + Flutter 3.24.5

## 基本用法

由于在Docker构建过程中安装Android SDK组件可能会遇到各种问题，我们提供了两种不同的方案：

1. **标准方案**（使用 Dockerfile）：在构建镜像时安装所有组件
2. **轻量方案**（使用 Dockerfile.minimal）：镜像构建时不安装Android SDK组件，而是在容器运行时通过脚本手动安装

当前默认使用轻量方案（Dockerfile.minimal），这样可以更灵活地处理SDK安装问题。

我们提供了以下几种Docker使用方式，满足不同的开发和构建需求：

### 1. 交互式开发环境

启动一个带有完整Flutter和Android开发环境的容器，并进入交互式shell：

```bash
# 使用我们的脚本工具启动开发环境
./docker-build.sh dev
```

或者手动执行以下命令：

```bash
# 构建并启动开发容器
docker compose up -d flutter

# 进入容器的交互式shell
docker compose exec flutter bash
```

容器启动后，您可能需要先安装Android SDK组件（仅在使用轻量方案时需要）：

```bash
# 在容器内运行安装脚本
./setup-android-sdk.sh
```

然后您就可以执行Flutter命令了：

```bash
# 在容器内运行
flutter pub get
flutter run -d [设备ID]
```

### 2. 构建Android APK

直接构建Android APK，无需进入交互式shell：

```bash
# 使用脚本工具构建Android APK
./docker-build.sh apk
```

或者手动执行：

```bash
# 构建Android APK
docker compose run build_apk
```

这个命令会自动安装必要的Android SDK组件（如果使用轻量方案），然后执行构建过程。构建完成后，您可以在`build/app/outputs/flutter-apk/`目录下找到生成的APK文件。

### 3. 构建Web应用

构建Flutter Web应用：

```bash
# 使用脚本工具构建Web应用
./docker-build.sh web
```

或者手动执行：

```bash
# 构建Web应用
docker compose run build_web
```

构建完成后，您可以在`build/web/`目录下找到生成的Web应用文件。

### 4. 手动安装Android SDK组件

如果您正在使用轻量方案，并且需要手动安装Android SDK组件，可以运行：

```bash
# 使用脚本工具安装SDK组件
./docker-build.sh setup-sdk
```

这将启动容器并运行SDK安装脚本，为您安装所需的所有Android SDK组件。

## 高级用法

### 自定义构建命令

您可以在docker-compose.yml文件中修改命令，或者直接通过命令行传递自定义命令：

```bash
# 运行自定义Flutter命令
docker compose run flutter flutter build apk --split-per-abi

# 如果需要确保Android SDK已安装
docker compose run flutter bash -c "./setup-android-sdk.sh && flutter build apk --split-per-abi"
```

### 使用Web服务器

如果您想在容器内启动Web服务器并访问Flutter Web应用，请修改docker-compose.yml文件，取消ports部分的注释，然后：

```bash
# 启动Web服务器
docker compose run -p 8080:8080 flutter bash -c "flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0"
```

然后在浏览器中访问 `http://localhost:8080`。

### 清理构建缓存

如果需要清理Flutter和Gradle缓存：

```bash
# 使用脚本工具清理缓存
./docker-build.sh clean

# 或者手动执行
docker compose down -v
```

## 故障排除

1. **Docker构建过程失败**：
   - 如果在构建过程中遇到与Android SDK有关的错误，请考虑使用轻量方案（Dockerfile.minimal）
   - 确保使用了正确的Docker和Docker Compose版本
   - 检查磁盘空间是否充足

2. **Android SDK安装失败**：
   - 使用轻量方案，然后手动运行SDK安装：`./docker-build.sh setup-sdk`
   - 如果特定组件安装失败，您可以编辑setup-android-sdk.sh脚本，移除不必要的组件
   - 在容器内尝试直接运行sdkmanager命令：
     ```bash
     yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platforms;android-33"
     ```

3. **网络问题**：
   - 检查您的网络连接
   - 尝试在Dockerfile中添加适当的代理设置：
     ```dockerfile
     # 在Dockerfile顶部添加
     ENV HTTP_PROXY=http://your-proxy:port
     ENV HTTPS_PROXY=http://your-proxy:port
     ```
   - 如果在中国大陆使用，可以考虑使用镜像源：
     ```dockerfile
     # Flutter镜像
     ENV PUB_HOSTED_URL=https://pub.flutter-io.cn
     ENV FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
     ```

4. **Flutter版本问题**：
   - 当前配置使用Flutter 3.24.5，如需更改，修改Dockerfile或Dockerfile.minimal中的此行：
     ```dockerfile
     curl -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
     ```
   - 请确保使用的Flutter版本与项目的需求兼容

5. **Java相关问题**：
   - 当前配置使用Java 17，这是Android SDK命令行工具所需的最低版本
   - 如果遇到 `UnsupportedClassVersionError` 错误，确保您使用的是Java 17或更高版本
   - 如果遇到其他Java相关错误，检查环境变量是否正确设置
   - 您可能需要调整Dockerfile中的JAVA_HOME路径，确保它指向正确的Java安装目录
   - 错误 "Warning: Failed to find package..." 通常可以忽略，我们已在脚本中添加 `|| true` 来处理

6. **Git仓库所有权问题**：
   - 如果遇到 `fatal: detected dubious ownership in repository` 错误，这是因为Git安全性检查
   - 我们在Docker配置中已添加了自动修复，但如果仍然发生，可以在容器内手动运行：
     ```bash
     git config --global --add safe.directory /opt/flutter
     git config --global --add safe.directory /app
     ```
   - 或者更简单的解决方法是在运行Flutter命令时添加`--no-version-check`参数，例如：
     ```bash
     flutter --no-version-check pub get
     ```

7. **内存不足问题**：
   - Docker容器默认配置了4GB内存限制，如果您的机器资源有限，可以在docker-compose.yml中调低：
     ```yaml
     deploy:
       resources:
         limits:
           memory: 2G
     ```
   - 或者在机器资源充足的情况下增加限制：
     ```yaml
     deploy:
       resources:
         limits:
           memory: 6G
     ```

4. **Flutter或Android SDK版本问题**：
   - 如需使用特定版本，请修改Dockerfile中的下载URL
   - 当前配置使用Flutter 3.19.4，如需更改，修改此行：
     ```dockerfile
     curl -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.4-stable.tar.xz
     ```

## 选择最适合您的方案

我们提供了两种不同的Docker配置方案，您可以根据自己的需求选择：

### 方案 1: 标准方案 (Dockerfile)

- **优点**: 镜像构建完成后包含所有组件，无需额外设置
- **缺点**: 构建过程容易因网络或其他问题失败
- **适用场景**: CI/CD环境，网络稳定的情况

如果要使用此方案，修改docker-compose.yml文件中的dockerfile路径：

```yaml
services:
  flutter:
    build:
      context: .
      dockerfile: Dockerfile  # 从Dockerfile.minimal改为Dockerfile
```

### 方案 2: 轻量方案 (Dockerfile.minimal)

- **优点**: 构建镜像更快，更少失败风险，可以按需安装SDK组件
- **缺点**: 首次使用时需要额外步骤安装SDK
- **适用场景**: 本地开发，网络不稳定的环境

这是当前默认设置，在使用容器后需运行：`./setup-android-sdk.sh` 来安装SDK。

## 自定义Docker镜像

如果需要自定义Docker镜像，可以修改Dockerfile/Dockerfile.minimal和docker-compose.yml文件。常见的自定义包括：

1. 更改Flutter或Android SDK版本
2. 添加特定的系统依赖
3. 配置代理设置
4. 调整性能参数
5. 添加其他开发工具（例如VSCode服务器等）

## 注意事项

- iOS应用构建需要macOS环境，无法在标准Docker容器中完成
- 对于大型项目，构建过程可能需要较长时间
- 请确保分配给Docker的资源（CPU/内存）足够
- 首次构建镜像时间较长，请耐心等待

## 最佳实践

1. **缓存管理**：
   - Docker卷已配置为持久化Flutter和Gradle缓存
   - 避免频繁使用 `docker-compose down -v`，这会删除缓存并导致重新下载依赖
   - 如果遇到依赖问题，可以进入容器内手动执行 `flutter pub cache clean`

2. **安全考虑**：
   - 默认Dockerfile以root用户运行，这在开发环境中是可以接受的
   - 如果用于生产环境，应取消注释Dockerfile中的用户权限相关部分，使用非root用户
   - 确保您的项目不包含敏感信息或凭证

3. **多平台支持**：
   - 当前配置专注于Android和Web构建
   - 如需支持更多平台，可以添加相应的服务配置到docker-compose.yml中

4. **持续集成**：
   - 这些Docker配置非常适合用于CI/CD流程
   - 可以在GitHub Actions或GitLab CI中直接使用，自动构建和发布应用

## 快速参考

```bash
# 构建镜像
docker-compose build

# 启动开发环境
./docker-build.sh dev

# 构建Android APK
./docker-build.sh apk

# 构建Web应用
./docker-build.sh web

# 清理环境
./docker-build.sh clean
```