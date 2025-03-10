#!/bin/bash

# Claude Tools Installer
# This script installs the Claude tools to your system

set -e  # Exit on error

INSTALL_DIR="$HOME/bin"
VIM_PLUGIN_DIR="$HOME/.vim/plugin"

# Create directories if they don't exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$VIM_PLUGIN_DIR"

# Copy CLI tools
echo "Installing Claude CLI tools to $INSTALL_DIR..."
cp bin/claude-ask "$INSTALL_DIR/"
cp bin/claude-bash "$INSTALL_DIR/"
cp bin/claude-fix "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/claude-ask"
chmod +x "$INSTALL_DIR/claude-bash"
chmod +x "$INSTALL_DIR/claude-fix"

# Install Vim plugin
echo "Installing Claude Vim plugin to $VIM_PLUGIN_DIR..."
cp vim/claude-vim.vim "$VIM_PLUGIN_DIR/"

echo "Installation complete!"
echo ""
echo "Make sure $INSTALL_DIR is in your PATH."
echo "To check if it's already there, run: echo \$PATH"
echo "If not, add it to your shell configuration:"
echo "  echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> ~/.bashrc"
echo ""
echo "Also ensure you have set up your Claude API key with tulikieli:"
echo "  tulikieli add claude api_key"
