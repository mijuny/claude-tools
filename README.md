# Claude Tools

A collection of command-line tools and Vim integration for interacting with Claude AI.

## Overview

This repository contains several tools for using Claude AI in your daily workflow:

1. **claude-ask** - Command-line tool for asking Claude questions and getting responses
2. **claude-bash** - Generate and execute bash commands using natural language
3. **claude-fix** - Fix issues in scripts and files using Claude
4. **claude-agent** - A CLI agent that uses Claude AI to execute system tasks
5. **claude-vim** - Vim plugin for seamless Claude integration in your editor

All tools use the secure `tulikieli` credential manager to retrieve your Claude API key.

## Installation

### Prerequisites

- Arch Linux (or other Linux distribution with minimal adjustments)
- `jq` package installed (`sudo pacman -S jq`)
- `curl` package installed (usually pre-installed)
- [Tulenkantajat](https://github.com/mijuny/tulenkantajat) secure credential manager set up with your Claude API key

### Setting Up Your Claude API Key

This project uses [Tulenkantajat](https://github.com/mijuny/tulenkantajat), a secure GPG-based credentials management system, to safely store and retrieve your Claude API key.

```bash
# First install Tulenkantajat if you haven't already
# Follow the instructions at: https://github.com/mijuny/tulenkantajat

# Add your Claude API key to the credential manager
tulikieli add claude api_key "your_actual_api_key_here"
```

### Installing the Tools

1. Clone this repository or copy the scripts to your preferred location
2. Make the scripts executable:
   ```bash
   chmod +x ~/bin/claude-ask
   chmod +x ~/bin/claude-bash
   chmod +x ~/bin/claude-fix
   chmod +x ~/bin/claude-agent.sh
   ```
3. Ensure ~/bin is in your PATH:
   ```bash
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
   # Or for zsh
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
   ```
4. Install the Vim plugin by copying it to your Vim plugin directory:
   ```bash
   mkdir -p ~/.vim/plugin
   cp claude-vim.vim ~/.vim/plugin/
   ```

## Command-line Tools

### claude-ask

Ask Claude questions and receive answers directly in your terminal.

#### Usage

```bash
# Basic usage
claude-ask "What is quantum computing?"

# Process content from a file
cat file.txt | claude-ask "Summarize this text"

# Save response to a file
claude-ask -o response.md "Write a markdown document about climate change"
```

#### Options

- `-o FILE` - Save response to the specified file
- `-m MODEL` - Specify Claude model (default: claude-3-7-sonnet-20250219)
- `-t TOKENS` - Maximum tokens in response (default: 4096)
- `-v` - Verbose mode (show API request details)
- `-h` - Show help message

#### Features

- Process piped input for analyzing files
- Save responses to files
- Control model parameters
- Handles special characters and formatting correctly

### claude-bash

Generate and execute bash commands from natural language descriptions.

#### Usage

```bash
# Generate a command to list specific files
claude-bash "find all .sh files in my home directory"

# System information commands
claude-bash "show me my current disk usage"

# Network commands
claude-bash "find my ip address"
```

#### Features

- Generates bash commands based on natural language descriptions
- Shows the command and asks for confirmation before executing
- Allows editing the command before execution
- Automatically fixes common issues like unquoted wildcards
- Safety checks for potentially destructive commands

### claude-fix

Fix issues in scripts and code files using Claude.

#### Usage

```bash
# Fix issues in a script
claude-fix script.sh "Fix the error handling in this script"

# Update a configuration file
claude-fix config.json "Add proper indentation and comments"

# Fix a script and include its runtime output for context
claude-fix script.py "The script fails when processing empty input"
```

#### Features

- Reads a file, has Claude analyze and fix it
- Creates a backup of the original file (.bak extension)
- Preserves file permissions
- Performs sanity checks before updating the file
- Prompts for confirmation for significant changes

### claude-agent

A CLI agent that uses Claude AI to execute system tasks by determining and running the appropriate commands.

#### Usage

```bash
# Basic usage
claude-agent.sh "Collect all hardware information about my computer"

# Save output to a file
claude-agent.sh -o system_report.md "Generate a system report"

# Set a custom output directory
claude-agent.sh -d /path/to/output "Check disk usage and suggest cleanup"
```

#### Options

- `-o FILE` - Save final output to the specified file
- `-d DIRECTORY` - Output directory (default: ~/claude_agent)
- `-m MODEL` - Specify Claude model (default: claude-3-7-sonnet-20250219)
- `-i ITERATIONS` - Maximum iterations (default: 5)
- `-t TIMEOUT` - Command timeout in seconds (default: 30)
- `-v` - Verbose mode (show API requests and responses)
- `-r` - Force root access (use sudo for all commands)
- `-h` - Show help message

#### Features

- Intelligently breaks down complex tasks into step-by-step commands
- Creates detailed logs of all commands and their outputs
- Validates commands before execution for safety
- Handles sudo commands with user confirmation
- Timeouts for long-running commands
- Organizes outputs in session-based directories

## Vim Integration (claude-vim.vim)

Seamlessly use Claude AI directly within Vim.

### Commands

- `:AskClaude` - Ask Claude a question
- `:AskClaudeSelection` - Send selected text to Claude with an optional prompt
- `:AskClaudeBuffer` - Send the entire buffer/file to Claude for analysis

### Keyboard Mappings

- `<leader>ca` - Ask Claude (in normal mode) or send selection to Claude (in visual mode)
- `<leader>cf` - Send the entire file/buffer to Claude

### Usage Examples

#### Asking Questions

1. In normal mode, press `<leader>ca`
2. Type your question at the prompt
3. A new buffer opens with Claude's response

#### Analyzing Code

1. Select code in visual mode (`v`)
2. Press `<leader>ca`
3. Enter a prompt like "Explain this code" or "Fix these bugs"
4. Claude analyzes the selection and shows results in a new buffer

#### Processing an Entire File

1. With a file open in Vim, press `<leader>cf`
2. Enter a prompt like "Refactor this script" or "Optimize this code"
3. Claude processes the entire file and shows results in a new buffer

### Moving Between Buffers

After Claude responds in a new buffer, you can navigate between buffers:
- `Ctrl+o` - Jump back to previous buffer
- `Ctrl+i` - Jump forward
- `Ctrl+^` - Toggle between current and last buffer
- `:bp` and `:bn` - Previous and next buffer

## Tips and Best Practices

1. **For code analysis**: Use specific prompts like "Find bugs" or "Optimize this function" rather than general ones.

2. **For document creation**: Use `claude-ask -o filename.md` to directly save responses to files.

3. **For shell commands**: When using `claude-bash`, review the command before execution, especially for file operations.

4. **For the agent**: When using `claude-agent.sh`, provide clear task descriptions and review any sudo commands before confirming execution.

5. **Vim workflow**: Use split windows (`Ctrl+w s` or `Ctrl+w v`) to view Claude's response alongside your code.

6. **Security**: Review all commands from `claude-bash` and `claude-agent.sh` before execution.

## Troubleshooting

### API Key Issues

If you see "Could not retrieve Claude API key":
```bash
tulikieli get claude api_key
```
If this doesn't return your API key, add it with:
```bash
tulikieli add claude api_key "your_actual_api_key_here"
```

If you're having issues with the Tulenkantajat credential manager:
```bash
# Check if Tulikieli is properly installed
which tulikieli

# View available credentials
tulikieli list

# Check the Tulenkantajat project documentation for more help
# https://github.com/mijuny/tulenkantajat
```

### Command Not Found

If you see "command not found" errors, ensure the scripts are executable and in your PATH:
```bash
chmod +x ~/bin/claude-*
echo $PATH  # Verify ~/bin is included
```

### Vim Plugin Not Working

If Vim commands aren't recognized:
```vim
:scriptnames  " Check if claude-vim.vim is listed
:source ~/.vim/plugin/claude-vim.vim  " Reload the plugin
```

## License

These tools are provided under the MIT License.

## Acknowledgments

- Developed for personal use with the Claude API by Anthropic.
- Uses [Tulenkantajat](https://github.com/mijuny/tulenkantajat) for secure credential management.

