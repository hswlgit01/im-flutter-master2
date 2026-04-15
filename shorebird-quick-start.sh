#!/bin/bash
# Shorebird 热更新快速开始脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Shorebird 热更新快速配置向导${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# 检查是否在 im-flutter 目录
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}错误: 请在 im-flutter 项目根目录下运行此脚本${NC}"
    exit 1
fi

# 步骤 1: 检查 Shorebird CLI
echo -e "${GREEN}步骤 1: 检查 Shorebird CLI${NC}"
if command -v shorebird &> /dev/null; then
    SHOREBIRD_VERSION=$(shorebird --version 2>&1 | head -1)
    echo -e "${GREEN}✓${NC} Shorebird CLI 已安装: $SHOREBIRD_VERSION"
else
    echo -e "${YELLOW}⚠${NC}  Shorebird CLI 未安装"
    echo ""
    echo "是否现在安装? (需要网络连接)"
    echo "1) 是"
    echo "2) 否 (稍后手动安装)"
    read -p "请选择 [1-2]: " install_choice

    if [ "$install_choice" = "1" ]; then
        echo "正在安装 Shorebird CLI..."
        curl --proto '=https' --tlsv1.2 \
            https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh \
            -sSf | bash

        # 添加到 PATH
        export PATH="$HOME/.shorebird/bin:$PATH"

        echo -e "${GREEN}✓${NC} Shorebird CLI 安装完成"
    else
        echo ""
        echo "请手动安装 Shorebird CLI:"
        echo "  curl --proto '=https' --tlsv1.2 \\"
        echo "    https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh \\"
        echo "    -sSf | bash"
        echo ""
        exit 0
    fi
fi

# 步骤 2: 登录 Shorebird
echo ""
echo -e "${GREEN}步骤 2: 登录 Shorebird 账号${NC}"
echo "如果还没有账号,请先访问 https://console.shorebird.dev/ 注册"
echo ""
echo "选择登录方式:"
echo "1) 浏览器登录 (推荐)"
echo "2) 使用 CI Token"
echo "3) 跳过 (稍后手动登录)"
read -p "请选择 [1-3]: " login_choice

case $login_choice in
    1)
        echo "打开浏览器登录..."
        shorebird login
        ;;
    2)
        read -p "请输入你的 Shorebird CI Token: " token
        shorebird login --ci-token "$token"
        ;;
    3)
        echo -e "${YELLOW}跳过登录,稍后可执行:${NC} shorebird login"
        ;;
esac

# 步骤 3: 初始化项目
echo ""
echo -e "${GREEN}步骤 3: 初始化 Shorebird 项目${NC}"
if [ -f "shorebird.yaml" ]; then
    echo -e "${YELLOW}⚠${NC}  检测到已存在 shorebird.yaml"
    read -p "是否重新初始化? [y/N]: " reinit
    if [[ $reinit =~ ^[Yy]$ ]]; then
        shorebird init
    else
        echo "保留现有配置"
    fi
else
    echo "初始化项目..."
    shorebird init
fi

# 步骤 4: 添加 Flutter 依赖
echo ""
echo -e "${GREEN}步骤 4: 添加 Flutter 依赖${NC}"
if grep -q "shorebird_code_push" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} 依赖已存在"
else
    echo "是否添加 shorebird_code_push 依赖到 pubspec.yaml?"
    echo "1) 是"
    echo "2) 否 (手动添加)"
    read -p "请选择 [1-2]: " dep_choice

    if [ "$dep_choice" = "1" ]; then
        echo "添加依赖..."
        flutter pub add shorebird_code_push
    else
        echo ""
        echo "请手动在 pubspec.yaml 中添加:"
        echo "  dependencies:"
        echo "    shorebird_code_push: ^1.1.0"
        echo ""
    fi
fi

# 步骤 5: 集成代码
echo ""
echo -e "${GREEN}步骤 5: 代码集成${NC}"
echo "已为你准备好集成代码:"
echo "  - lib/utils/hot_update_manager.dart (热更新管理器)"
echo "  - SHOREBIRD_SETUP.md (详细文档)"
echo ""
echo "请在 lib/main.dart 中添加以下代码:"
echo ""
echo -e "${YELLOW}import 'utils/hot_update_manager.dart';${NC}"
echo ""
echo -e "${YELLOW}void main() async {${NC}"
echo -e "${YELLOW}  WidgetsFlutterBinding.ensureInitialized();${NC}"
echo -e "${YELLOW}  ${NC}"
echo -e "${YELLOW}  runApp(MyApp());${NC}"
echo -e "${YELLOW}  ${NC}"
echo -e "${YELLOW}  // 应用启动后检查更新${NC}"
echo -e "${YELLOW}  Future.delayed(Duration(seconds: 3), () {${NC}"
echo -e "${YELLOW}    HotUpdateManager().checkUpdateOnStartup();${NC}"
echo -e "${YELLOW}  });${NC}"
echo -e "${YELLOW}}${NC}"
echo ""

# 完成
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}✓ 配置完成!${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "接下来的操作:"
echo ""
echo "1️⃣  发布基础版本 (首次):"
echo "   shorebird release android"
echo ""
echo "2️⃣  构建并测试:"
echo "   flutter build apk --dart-define=ENV=dev"
echo "   # 安装到设备测试"
echo ""
echo "3️⃣  修改代码后推送热更新:"
echo "   shorebird patch android"
echo ""
echo "4️⃣  查看发布历史:"
echo "   shorebird releases list"
echo "   shorebird patches list"
echo ""
echo "5️⃣  详细文档:"
echo "   cat SHOREBIRD_SETUP.md"
echo ""
echo -e "${YELLOW}提示: 首次发布前请确保已登录 Shorebird 账号${NC}"
echo ""
