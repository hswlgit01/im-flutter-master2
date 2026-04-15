FROM ubuntu:22.04

# 避免在构建过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置环境变量
ENV FLUTTER_HOME=/opt/flutter
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=/opt/android
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=${PATH}:${FLUTTER_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    xz-utils \
    openjdk-17-jdk \
    libglu1-mesa \
    cmake \
    ninja-build \
    clang \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-11-dev \
    && apt-get clean

# 创建必要的目录
RUN mkdir -p ${FLUTTER_HOME} ${ANDROID_HOME}/cmdline-tools

# 下载并安装 Flutter SDK
RUN cd ${FLUTTER_HOME} && \
    curl -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz && \
    tar xf flutter.tar.xz --strip-components=1 && \
    rm flutter.tar.xz && \
    # 确保Flutter命令可用
    flutter --version

# 下载并安装 Android 命令行工具
RUN cd ${ANDROID_HOME}/cmdline-tools && \
    curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip && \
    unzip cmdline-tools.zip && \
    mkdir -p latest && \
    mv cmdline-tools/* latest/ 2>/dev/null || true && \
    rmdir cmdline-tools 2>/dev/null || true && \
    rm cmdline-tools.zip

# 确保工具在PATH中可用并检查环境配置
RUN ls -la ${ANDROID_HOME}/cmdline-tools/latest/bin/ && \
    echo "PATH: ${PATH}" && \
    echo "JAVA_HOME: ${JAVA_HOME}" && \
    java -version

# 接受Android SDK许可证
RUN mkdir -p ${ANDROID_HOME}/licenses && \
    echo "8933bad161af4178b1185d1a37fbf41ea5269c55" > ${ANDROID_HOME}/licenses/android-sdk-license && \
    echo "d56f5187479451eabf01fb78af6dfcb131a6481e" >> ${ANDROID_HOME}/licenses/android-sdk-license && \
    echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" >> ${ANDROID_HOME}/licenses/android-sdk-license

# 安装Android SDK组件
# 使用绝对路径运行sdkmanager以避免PATH问题
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --verbose "platform-tools"
# 等待确保第一个命令成功完成后再执行后续命令
RUN sleep 3 && echo "Continuing with Android SDK installation..."
# 分步骤安装其他Android SDK组件
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --verbose "platforms;android-33" || echo "Failed to install platforms;android-33, continuing anyway"
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --verbose "build-tools;33.0.0" || echo "Failed to install build-tools;33.0.0, continuing anyway"
# 以下组件库可能已不再可用或已更改，尝试安装但允许失败
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --verbose "extras;android;m2repository" || echo "Failed to install extras;android;m2repository, continuing anyway"
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --verbose "extras;google;m2repository" || echo "Failed to install extras;google;m2repository, continuing anyway"

# 预先下载Flutter依赖
RUN flutter precache

# 安装 Shorebird CLI
ENV SHOREBIRD_HOME=/root/.shorebird
ENV PATH=${PATH}:${SHOREBIRD_HOME}/bin
RUN curl --proto '=https' --tlsv1.2 \
    https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh \
    -sSf | bash && \
    # 验证安装
    shorebird --version

# 配置Git安全目录以避免所有权问题
RUN git config --system --add safe.directory ${FLUTTER_HOME} && \
    git config --system --add safe.directory /app

# 检查Flutter安装
RUN flutter doctor -v

# 创建工作目录
WORKDIR /app

# 构建参数：支持 dev, test, prod 三种环境
ARG BUILD_ENV=dev

# 将构建参数传递给环境变量（供 Flutter 构建时使用）
ENV BUILD_ENV=${BUILD_ENV}

# 设置用户权限（可选，如果您想以非root用户运行）
# RUN groupadd -r flutter && useradd -r -g flutter flutter
# RUN chown -R flutter:flutter /app ${FLUTTER_HOME}
# USER flutter

# 暴露端口（可选，用于Web服务器）
# EXPOSE 8080

# 配置默认命令
CMD ["bash"]