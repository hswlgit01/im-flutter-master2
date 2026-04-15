#!/bin/bash
# Shorebird 容器内辅助脚本
# 在容器内使用: ./shorebird-helper.sh [命令]

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

function show_help {
  echo -e "${BLUE}================================${NC}"
  echo -e "${BLUE}Shorebird 容器内快捷命令${NC}"
  echo -e "${BLUE}================================${NC}"
  echo ""
  echo "用法: ./shorebird-helper.sh [命令] [环境]"
  echo ""
  echo "命令:"
  echo "  login       登录 Shorebird"
  echo "  init        初始化项目"
  echo "  release     发布基础版本 (生成 AAB)"
  echo "  release-apk 发布基础版本 (生成 APK)"
  echo "  patch       推送热更新补丁"
  echo "  list        查看发布历史"
  echo "  account     查看账号信息"
  echo "  doctor      检查 Shorebird 环境"
  echo "  help        显示此帮助"
  echo ""
  echo "环境 (可选):"
  echo "  dev         开发环境 (默认)"
  echo "  test        测试环境"
  echo "  prod        生产环境"
  echo ""
  echo "示例:"
  echo "  ./shorebird-helper.sh login          # 登录"
  echo "  ./shorebird-helper.sh init           # 初始化项目"
  echo "  ./shorebird-helper.sh release        # 发布开发版本"
  echo "  ./shorebird-helper.sh release prod   # 发布生产版本"
  echo "  ./shorebird-helper.sh patch dev      # 推送开发补丁"
  echo "  ./shorebird-helper.sh list           # 查看历史"
  echo ""
  echo "或直接使用 shorebird 命令:"
  echo "  shorebird --version"
  echo "  shorebird releases list"
  echo "  shorebird patches list --release-version=X"
  echo ""
}

ENV=${2:-dev}

case "$1" in
  login)
    echo -e "${YELLOW}登录 Shorebird...${NC}"
    echo ""
    echo "选择登录方式:"
    echo "1) 浏览器登录 (推荐)"
    echo "2) CI Token"
    read -p "请选择 [1-2]: " choice

    case $choice in
      1)
        shorebird login
        ;;
      2)
        read -p "请输入 CI Token: " token
        shorebird login --ci-token "$token"
        ;;
      *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
    esac
    ;;

  init)
    echo -e "${YELLOW}初始化 Shorebird 项目...${NC}"
    shorebird init
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}初始化成功! 已创建 shorebird.yaml${NC}"
    fi
    ;;

  release)
    echo -e "${YELLOW}发布基础版本 (环境: ${ENV})...${NC}"

    CMD="flutter pub get && shorebird release android --flutter-version=3.24.5"
    if [ "$ENV" != "dev" ]; then
      CMD="$CMD --dart-define=ENV=$ENV"
    fi

    eval $CMD

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}发布成功!${NC}"
      echo -e "环境: ${BLUE}${ENV}${NC}"
      echo -e "AAB文件: ${BLUE}build/app/outputs/bundle/release/app-release.aab${NC}"
    fi
    ;;

  release-apk)
    echo -e "${YELLOW}发布基础版本 APK (环境: ${ENV})...${NC}"

    CMD="flutter pub get && shorebird release android --flutter-version=3.24.5 --artifact=apk"
    if [ "$ENV" != "dev" ]; then
      CMD="$CMD --dart-define=ENV=$ENV"
    fi

    eval $CMD

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}发布成功!${NC}"
      echo -e "环境: ${BLUE}${ENV}${NC}"
      echo -e "APK文件: ${BLUE}build/app/outputs/apk/release/app-release.apk${NC}"
    fi
    ;;

  patch)
    echo -e "${YELLOW}推送热更新补丁 (环境: ${ENV})...${NC}"

    CMD="flutter pub get && shorebird patch android"
    if [ "$ENV" != "dev" ]; then
      CMD="$CMD --dart-define=ENV=$ENV"
    fi

    # 可选: 指定版本
    read -p "是否指定目标版本? [y/N]: " specify
    if [[ $specify =~ ^[Yy]$ ]]; then
      read -p "请输入版本号 (如: 0.7.0+1): " version
      CMD="$CMD --release-version=$version"
    fi

    eval $CMD

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}补丁推送成功!${NC}"
      echo -e "环境: ${BLUE}${ENV}${NC}"
    fi
    ;;

  list)
    echo -e "${BLUE}=== 发布列表 ===${NC}"
    shorebird releases list
    echo ""
    read -p "查看某版本的补丁? [y/N]: " show_patches
    if [[ $show_patches =~ ^[Yy]$ ]]; then
      read -p "版本号: " version
      echo -e "${BLUE}=== 补丁列表 (${version}) ===${NC}"
      shorebird patches list --release-version="$version"
    fi
    ;;

  account)
    echo -e "${BLUE}=== 账号信息 ===${NC}"
    shorebird account
    ;;

  doctor)
    echo -e "${BLUE}=== Shorebird 环境检查 ===${NC}"
    shorebird doctor
    ;;

  help|--help|-h|"")
    show_help
    ;;

  *)
    echo -e "${RED}未知命令: $1${NC}"
    echo ""
    show_help
    exit 1
    ;;
esac
