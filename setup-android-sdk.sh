#!/bin/bash

# 安装Android SDK组件的脚本
# 这个脚本应该在容器内运行，用于安装Android SDK组件

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 显示帮助信息
function show_help {
  echo -e "${BLUE}Android SDK安装工具${NC}"
  echo ""
  echo "用法: $0"
  echo ""
  echo "此脚本安装Android开发所需的基本SDK组件。"
  echo "它应该在Docker容器内运行。"
}

# 检查环境变量
function check_env {
  if [ -z "$ANDROID_HOME" ]; then
    echo -e "${RED}错误: ANDROID_HOME 环境变量未设置${NC}"
    exit 1
  fi

  if [ -z "$ANDROID_SDK_ROOT" ]; then
    echo -e "${RED}错误: ANDROID_SDK_ROOT 环境变量未设置${NC}"
    exit 1
  fi

  if [ ! -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]; then
    echo -e "${RED}错误: Android命令行工具未安装或路径不正确${NC}"
    echo "期望路径: $ANDROID_HOME/cmdline-tools/latest/bin"
    exit 1
  fi
}

# 安装SDK组件
function install_sdk_components {
  local sdkmanager="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

  echo -e "${YELLOW}接受许可协议...${NC}"
  yes | $sdkmanager --licenses >/dev/null

  echo -e "${YELLOW}安装 platform-tools...${NC}"
  yes | $sdkmanager --verbose "platform-tools"

  echo -e "${YELLOW}安装 platforms;android-33...${NC}"
  yes | $sdkmanager --verbose "platforms;android-33" || echo -e "${YELLOW}安装失败，继续执行...${NC}"

  echo -e "${YELLOW}安装 build-tools;33.0.0...${NC}"
  yes | $sdkmanager --verbose "build-tools;33.0.0" || echo -e "${YELLOW}安装失败，继续执行...${NC}"

  echo -e "${YELLOW}安装 extras;android;m2repository...${NC}"
  yes | $sdkmanager --verbose "extras;android;m2repository" || echo -e "${YELLOW}安装失败，继续执行...${NC}"

  echo -e "${YELLOW}安装 extras;google;m2repository...${NC}"
  yes | $sdkmanager --verbose "extras;google;m2repository" || echo -e "${YELLOW}安装失败，继续执行...${NC}"

  # 检查安装结果
  echo -e "${YELLOW}已安装的包:${NC}"
  $sdkmanager --list_installed
}

# 配置Git安全目录
function setup_git_safe_directories {
  echo -e "${YELLOW}配置Git安全目录...${NC}"
  if [ -n "$FLUTTER_HOME" ] && [ -d "$FLUTTER_HOME" ]; then
    git config --global --add safe.directory $FLUTTER_HOME
    echo -e "${GREEN}已添加Flutter目录($FLUTTER_HOME)为Git安全目录${NC}"
  fi

  git config --global --add safe.directory /app
  echo -e "${GREEN}已添加工作目录(/app)为Git安全目录${NC}"
}

# 主函数
function main {
  echo -e "${GREEN}开始设置Android SDK...${NC}"
  setup_git_safe_directories
  check_env
  install_sdk_components
  echo -e "${GREEN}Android SDK设置完成!${NC}"
}

# 处理命令行参数
if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  show_help
  exit 0
fi

main