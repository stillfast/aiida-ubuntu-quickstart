#!/bin/bash

# ==================== CONFIGURABLE VARIABLES ====================

ZSH_THEME="robbyrussell"
ZSH_PLUGINS="(git z zsh-autosuggestions zsh-syntax-highlighting)"
CUSTOM_ALIASES="alias vr='verdi run'
alias vpl='verdi process list'
alias vplaw='verdi plugin list aiida.workflows'
alias vplac='verdi plugin list aiida.calculations'
alias vpr='verdi process report'
alias vpp='verdi process play'"

USE_PROXY="false"
HTTPS_PROXY_ADDR="http://127.0.0.1:7890"

OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
GIT_TIMEOUT=30

# ==================== INSTALLATION SCRIPT ====================

set -e

echo "========================================="
echo "Installing zsh and oh-my-zsh..."
echo "========================================="

if [ "$USE_PROXY" = "true" ]; then
    export HTTPS_PROXY="$HTTPS_PROXY_ADDR"
    export HTTP_PROXY="$HTTPS_PROXY_ADDR"
fi

echo -e "\n[1/4] Checking zsh..."
if ! command -v zsh &> /dev/null; then
    if command -v conda &> /dev/null; then
        echo "Installing zsh via conda..."
        conda install -y -c conda-forge zsh
    else
        echo "Error: zsh not found and conda not available"
        exit 1
    fi
fi
echo "zsh found at $(command -v zsh)"

echo -e "\n[2/4] Installing oh-my-zsh..."
if [ -d "$OH_MY_ZSH_DIR" ]; then
    echo "oh-my-zsh already installed, skipping"
else
    echo "Cloning oh-my-zsh (timeout: ${GIT_TIMEOUT}s)..."
    timeout $GIT_TIMEOUT git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$OH_MY_ZSH_DIR" || {
        echo "Clone failed. Trying tarball..."
        cd $HOME
        timeout $GIT_TIMEOUT wget -q https://github.com/ohmyzsh/ohmyzsh/archive/refs/heads/master.tar.gz -O ohmyzsh.tar.gz
        tar -xzf ohmyzsh.tar.gz && mv oh-my-zsh-master .oh-my-zsh && rm ohmyzsh.tar.gz
    }
fi

echo -e "\n[3/4] Installing plugins..."
PLUGINS_DIR="$OH_MY_ZSH_DIR/plugins"
mkdir -p "$PLUGINS_DIR"

for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting; do
    plugin_name=$(basename $repo)
    if [ ! -d "$PLUGINS_DIR/$plugin_name" ]; then
        echo "Installing $plugin_name..."
        timeout $GIT_TIMEOUT git clone "https://github.com/$repo.git" "$PLUGINS_DIR/$plugin_name" || {
            echo "Warning: Failed to install $plugin_name"
        }
    else
        echo "$plugin_name already installed"
    fi
done

echo -e "\n[4/4] Configuring .zshrc..."
if [ -f "$HOME/.zshrc" ]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
fi

cp "$OH_MY_ZSH_DIR/templates/zshrc.zsh-template" "$HOME/.zshrc"
sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"$ZSH_THEME\"/" "$HOME/.zshrc"
sed -i "s/^plugins=.*/plugins=$ZSH_PLUGINS/" "$HOME/.zshrc"

if [ -n "$CUSTOM_ALIASES" ]; then
    echo "" >> "$HOME/.zshrc"
    echo "# Custom aliases" >> "$HOME/.zshrc"
    echo "$CUSTOM_ALIASES" >> "$HOME/.zshrc"
fi

echo ""
echo "========================================="
echo "Installation completed!"
echo "========================================="
echo "Run: exec zsh"
echo "Config: $HOME/.zshrc"

