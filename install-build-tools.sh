#!/bin/bash
# 在容器内安装 Android Build Tools (apksigner, zipalign)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}安装 Android Build Tools${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# 检查是否在容器内
if [ ! -d "/opt/android" ]; then
    echo -e "${RED}错误: 此脚本应在 Docker 容器内运行${NC}"
    echo ""
    echo "请执行:"
    echo "  ./docker-build.sh start_dev"
    echo "  ./install-build-tools.sh"
    exit 1
fi

ANDROID_HOME=${ANDROID_HOME:-/opt/android}

echo -e "${YELLOW}Android SDK 路径: $ANDROID_HOME${NC}"
echo ""

# 检查 sdkmanager 是否可用
if ! command -v sdkmanager &> /dev/null; then
    echo -e "${RED}错误: sdkmanager 未找到${NC}"
    echo "请确保 Android SDK 命令行工具已安装"
    exit 1
fi

echo -e "${YELLOW}1. 接受 Android SDK 许可证...${NC}"
yes | sdkmanager --licenses

echo ""
echo -e "${YELLOW}2. 安装 Build Tools 34.0.0...${NC}"
sdkmanager "build-tools;34.0.0"

echo ""
echo -e "${YELLOW}3. 安装 Platform Tools...${NC}"
sdkmanager "platform-tools"

echo ""
echo -e "${YELLOW}4. 安装 Android Platform 34...${NC}"
sdkmanager "platforms;android-34"

# 添加到 PATH
BUILD_TOOLS_PATH="${ANDROID_HOME}/build-tools/34.0.0"
if [ -d "$BUILD_TOOLS_PATH" ]; then
    echo ""
    echo -e "${GREEN}安装成功!${NC}"
    echo ""
    echo -e "Build Tools 路径: ${BLUE}$BUILD_TOOLS_PATH${NC}"
    echo ""

    # 检查工具是否可用
    echo -e "${YELLOW}验证工具...${NC}"

    if [ -f "$BUILD_TOOLS_PATH/apksigner" ]; then
        echo -e "  ✓ apksigner: ${GREEN}已安装${NC}"
        APKSIGNER_VERSION=$("$BUILD_TOOLS_PATH/apksigner" --version 2>&1 || echo "unknown")
        echo -e "    版本: $APKSIGNER_VERSION"
    else
        echo -e "  ✗ apksigner: ${RED}未找到${NC}"
    fi

    if [ -f "$BUILD_TOOLS_PATH/zipalign" ]; then
        echo -e "  ✓ zipalign: ${GREEN}已安装${NC}"
    else
        echo -e "  ✗ zipalign: ${RED}未找到${NC}"
    fi

    # 添加到当前会话的 PATH
    export PATH="${PATH}:${BUILD_TOOLS_PATH}"

    echo ""
    echo -e "${YELLOW}添加到 PATH (当前会话):${NC}"
    echo -e "  export PATH=\"\${PATH}:${BUILD_TOOLS_PATH}\""
    echo ""
    echo -e "${YELLOW}永久添加到 PATH:${NC}"
    echo -e "  请在 ~/.bashrc 或容器的 .bashrc_docker 中添加:"
    echo -e "  ${BLUE}export PATH=\"\${PATH}:${BUILD_TOOLS_PATH}\"${NC}"
    echo ""

    # 自动添加到 .bashrc_docker
    if [ -f "/app/.bashrc_docker" ]; then
        if ! grep -q "build-tools" /app/.bashrc_docker; then
            echo "" >> /app/.bashrc_docker
            echo "# Android Build Tools" >> /app/.bashrc_docker
            echo "export PATH=\"\${PATH}:${BUILD_TOOLS_PATH}\"" >> /app/.bashrc_docker
            echo -e "${GREEN}已自动添加到 /app/.bashrc_docker${NC}"
        fi
    fi

    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}安装完成!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo "现在可以使用:"
    echo -e "  ${YELLOW}apksigner --version${NC}"
    echo -e "  ${YELLOW}zipalign --help${NC}"
    echo -e "  ${YELLOW}./sign-apk.sh <apk文件>${NC}"
    echo ""
else
    echo -e "${RED}安装失败: Build Tools 目录未找到${NC}"
    exit 1
fi
