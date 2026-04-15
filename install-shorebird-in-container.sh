#!/bin/bash
# 在运行中的容器内安装 Shorebird 的脚本

echo "正在安装 Shorebird CLI..."

# 安装 Shorebird
curl --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh \
  -sSf | bash

# 添加到当前 shell 的 PATH
export PATH="$HOME/.shorebird/bin:$PATH"

# 验证安装
echo ""
echo "Shorebird 版本:"
shorebird --version

echo ""
echo "✓ Shorebird 安装完成!"
echo ""
echo "现在可以使用以下命令:"
echo "  shorebird login"
echo "  shorebird init"
echo "  shorebird release android"
echo ""
echo "或使用快捷命令:"
echo "  sb login"
echo "  sb release dev"
echo ""
