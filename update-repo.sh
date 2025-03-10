#!/bin/bash

# Update repository from installed versions
# This pulls changes from your active scripts back into the repo

set -e  # Exit on error

# Update CLI tools
echo "Updating CLI tools in repository..."
cp ~/bin/claude-ask bin/
cp ~/bin/claude-bash bin/
cp ~/bin/claude-fix bin/

# Update Vim plugin
echo "Updating Vim plugin in repository..."
cp ~/.vim/plugin/claude-vim.vim vim/

echo "Repository updated with your latest changes."
echo "Don't forget to commit these changes to git!"
