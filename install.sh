#!/usr/bin/env bash

# ====== 检查依赖 ======
if ! command -v brew &> /dev/null; then
  echo "错误：Homebrew 未安装！请先安装 Homebrew。"
  exit 1
fi

# ====== 配置常量 ======
SCRIPT_DIR="$HOME/brew_auto_update"  # 文件存放目录
PLIST_NAME="homebrew.auto.update.plist"
SCRIPT_NAME="homebrew.auto.update.sh"
MANAGE_SCRIPT="manage_task.sh"

# ====== 配置 HOMEBREW_CASK_OPTS ======
# 定义要添加的环境变量
CASK_OPTS='export HOMEBREW_CASK_OPTS="--appdir=~/Applications"'

# 检测用户的 Zsh 配置文件优先级
SHELL_CONFIG=""
if [ -n "$ZSH_VERSION" ]; then
  # 优先使用 .zprofile，若不存在则用 .zshrc
  if [ -f "$HOME/.zprofile" ]; then
    SHELL_CONFIG="$HOME/.zprofile"
  else
    SHELL_CONFIG="$HOME/.zshrc"
  fi
else
  echo "警告：非 Zsh 环境，将使用 Bash 配置。"
  # 检测配置文件（适配 Bash）
  SHELL_CONFIG=""
  if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bash_profile" ]; then
      SHELL_CONFIG="$HOME/.bash_profile"
    else
      SHELL_CONFIG="$HOME/.bashrc"
    fi
  else
    echo "警告：脚本需在 Bash 中运行。"
    exit 1
  fi
fi

# 避免重复写入
if ! grep -qF "$CASK_OPTS" "$SHELL_CONFIG"; then
  echo -e "\n# Homebrew Cask 应用安装目录\n$CASK_OPTS" >> "$SHELL_CONFIG"
fi

# 临时导出变量
eval "$CASK_OPTS"

# ====== 创建目录 ======
mkdir -p "$SCRIPT_DIR"
cd "$SCRIPT_DIR" || exit 1

# ====== 生成主脚本 (兼容 Bash) ======
cat > "$SCRIPT_NAME" << EOF
#!/usr/bin/env bash

# 加载 Homebrew 环境变量
eval "$(brew shellenv)"

# 更新操作
{
  echo "[$(date)] 开始更新..."
  brew update
  brew upgrade
  brew upgrade --greedy --cask
  brew cleanup
  echo "[$(date)] 更新完成"
} >> ~/brew_auto_update.log 2>&1
EOF

# ====== 生成 plist 配置文件 ======
cat > "$PLIST_NAME" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>homebrew.auto.update</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/$SCRIPT_NAME</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>10</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/brew_auto_update.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/brew_auto_update.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$(brew --prefix)/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

# ====== 生成管理脚本 ======
cat > "$MANAGE_SCRIPT" << EOF
#!/usr/bin/env bash

# 加载/卸载任务
PLIST_PATH="$SCRIPT_DIR/$PLIST_NAME"

echo "卸载旧任务..."
launchctl bootout "gui/\$UID" "\$PLIST_PATH" 2>/dev/null

echo "加载新任务..."
launchctl bootstrap "gui/\$UID" "\$PLIST_PATH"

echo "检查状态:"
launchctl print "gui/\$UID/homebrew.auto.update"
EOF

# ====== 设置权限 ======
chmod +x "$SCRIPT_NAME"
chmod +x "$MANAGE_SCRIPT"

# ====== 完成提示 ======
echo "✅ 懒人包生成完成！目录: $SCRIPT_DIR"
echo "👉 后续操作:"
echo "1. 编辑 plist 文件调整时间: cd $SCRIPT_DIR && open $PLIST_NAME"
echo "2. 启动任务: ./manage_task.sh"
echo "3. 查看日志: tail -f ~/brew_auto_update.log"
