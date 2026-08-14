#!/bin/bash

# ==========================================
# 🚀 开发环境一键配置脚本 (Ubuntu/Debian)
# 包含：Zsh + Oh My Zsh + 编程语言 + CLI 工具 + 代理 + SSH
# ==========================================

set -e

# --- 代理配置 ---
PROXY_ADDR="192.168.254.1:7890"
PROXY_URL="http://${PROXY_ADDR}"
export http_proxy="$PROXY_URL"
export https_proxy="$PROXY_URL"
export HTTP_PROXY="$PROXY_URL"
export HTTPS_PROXY="$PROXY_URL"

# --- 颜色输出 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- 0. 检测系统 ---
if [ ! -f /etc/os-release ]; then error "无法检测操作系统"; fi
. /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" && "$ID" != "linuxmint" ]]; then
    warning "本脚本主要为 Ubuntu/Debian 编写，其他发行版可能需要手动调整"
fi

# --- 1. 更新系统 & 安装基础工具 ---
info "🔄 更新系统并安装基础工具..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    zsh git curl wget vim tmux htop tree jq unzip \
    build-essential software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release openssh-server

# --- 2. 安装 Zsh & Oh My Zsh ---
info "💻 安装 Zsh & Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    info "Oh My Zsh 已存在，跳过"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
info "📦 安装 Zsh 插件 (自动补全 & 语法高亮)..."
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true

sed -i 's/^plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' ~/.zshrc

# >> Zsh 代理配置 + 开关函数
info "🌐 配置 Zsh 代理 (${PROXY_ADDR})..."
cat >> ~/.zshrc << EOF

# --- 代理配置 ---
PROXY_URL="$PROXY_URL"
PROXY_SOCKS="socks5://${PROXY_ADDR}"
export http_proxy="\$PROXY_URL"
export https_proxy="\$PROXY_URL"
export all_proxy="\$PROXY_SOCKS"
export no_proxy="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8"

proxy_on() {
    export http_proxy="\$PROXY_URL"
    export https_proxy="\$PROXY_URL"
    export all_proxy="\$PROXY_SOCKS"
    git config --global http.proxy "\$PROXY_URL"
    git config --global https.proxy "\$PROXY_URL"
    echo "✅ 代理已开启 (${PROXY_ADDR})"
}
proxy_off() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    echo "❌ 代理已关闭"
}
EOF

# --- 3. 安装编程语言 ---

# >> Python 3 🔧 修复 PEP 668
info "🐍 配置 Python 环境..."
sudo apt install -y python3-pip python3-venv python3-dev pipx
pipx ensurepath 2>/dev/null || true

# >> Node.js (via nvm)
info "📦 安装 Node.js (via nvm)..."
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'
npm install -g yarn pnpm

# >> Go
info "🐹 安装 Go..."
GO_VERSION="1.22.5"
if ! command -v go &>/dev/null; then
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
    echo 'export GOPATH=$HOME/go' >> ~/.zshrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
fi

# >> Rust
info "🦀 安装 Rust..."
if ! command -v rustc &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    echo 'source $HOME/.cargo/env' >> ~/.zshrc
fi

# >> C/C++ 开发环境
info "🔧 配置 C/C++ 开发环境..."
sudo apt install -y \
    cmake cmake-curses-gui \
    gdb lldb \
    clang clangd clang-format clang-tidy \
    valgrind cppcheck \
    bear \
    libboost-all-dev

# vcpkg
info "📦 安装 vcpkg (C++ 包管理器)..."
if [ ! -d "$HOME/vcpkg" ]; then
    git clone https://github.com/microsoft/vcpkg.git ~/vcpkg
    ~/vcpkg/bootstrap-vcpkg.sh
    echo 'export PATH="$HOME/vcpkg:$PATH"' >> ~/.zshrc
fi

# --- 4. Git 全局代理 ---
info "🌐 配置 Git 全局代理..."
git config --global http.proxy "$PROXY_URL"
git config --global https.proxy "$PROXY_URL"

# --- 5. 常用命令行工具 ---
info "🛠️ 安装现代 CLI 工具..."
sudo apt install -y bat ripgrep fd-find tldr 2>/dev/null || true
mkdir -p ~/.local/bin
command -v batcat &>/dev/null && ln -sf /usr/bin/batcat ~/.local/bin/bat 2>/dev/null || true
command -v fdfind &>/dev/null && ln -sf $(which fdfind) ~/.local/bin/fd 2>/dev/null || true

sudo apt install -y eza 2>/dev/null || {
    command -v cargo &>/dev/null && cargo install eza || warning "eza 安装失败"
}

LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo mv lazygit /usr/local/bin/
rm lazygit.tar.gz

echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# --- 6. 开启 SSH 服务 ---
info "🔐 配置 SSH 服务..."
sudo systemctl enable ssh
sudo systemctl start ssh
sudo ufw allow ssh 2>/dev/null && info "防火墙已放行 SSH (22)" || true

# --- 7. 设置 Zsh 为默认 Shell ---
info "🐚 切换默认 Shell 为 Zsh..."
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s $(which zsh)
fi

# --- 8. 完成 ---
info "✅ 环境配置完成！"
echo ""
echo -e "${YELLOW}已安装的内容：${NC}"
echo "  ✅ Zsh + Oh My Zsh (含 proxy_on/off 开关，同步管理 Git 代理)"
echo "  ✅ Git 全局代理 (${PROXY_ADDR})"
echo "  ✅ Python 3 + pip + pipx (venv 友好，无 PEP 668 报错)"
echo "  ✅ Node.js (LTS) + npm + yarn + pnpm"
echo "  ✅ Go"
echo "  ✅ Rust"
echo "  ✅ C/C++ (gcc, g++, clang, cmake, gdb, clangd, valgrind, vcpkg, boost)"
echo "  ✅ bat, ripgrep, fd, eza, tldr, lazygit"
echo "  ✅ SSH 服务 (已启动 + 开机自启)"
echo ""
echo -e "${YELLOW}下一步：${NC}"
echo "  🔸 重新打开终端 或运行: source ~/.zshrc"
echo "  🔸 查看虚拟机 IP: ip a | grep 'inet '"
echo "  🔸 从宿主机 SSH 连接: ssh $(whoami)@<虚拟机IP>"
echo "  🔸 开关代理: proxy_on / proxy_off"
echo "  🔸 Python 工具用 pipx 装: pipx install black"
echo "  🔸 Python 项目用 venv: python3 -m venv .venv && source .venv/bin/activate"
echo ""
echo -e "${GREEN}Enjoy your new dev environment! 🎉${NC}"
