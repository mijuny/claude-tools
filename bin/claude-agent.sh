#!/bin/bash

# claude-agent.sh - A CLI agent that uses Claude AI to execute system tasks
# Usage: 
#   claude-agent.sh "Collect all hardware information about my computer"
#   claude-agent.sh -o /path/to/output.txt "List all network connections"

set -e  # Exit on error

# Default settings
output_dir="$HOME/claude_agent"
output_file=""
max_iterations=5
model="claude-3-7-sonnet-20250219"
verbose=false
force_root=false
command_timeout=30  # Default timeout in seconds

# Show usage information
show_usage() {
  echo "Usage: claude-agent.sh [OPTIONS] \"task description\""
  echo "  -o FILE         Save final output to the specified file"
  echo "  -d DIRECTORY    Output directory (default: ~/claude_agent)"
  echo "  -m MODEL        Specify Claude model (default: claude-3-7-sonnet-20250219)"
  echo "  -i ITERATIONS   Maximum iterations (default: 5)"
  echo "  -t TIMEOUT      Command timeout in seconds (default: 30)"
  echo "  -v              Verbose mode (show API requests and responses)"
  echo "  -r              Force root access (use sudo for all commands)"
  echo "  -h              Show this help message"
  echo ""
  echo "Examples:"
  echo "  claude-agent.sh \"Collect all hardware information about my computer\""
  echo "  claude-agent.sh -o system_report.md \"Generate a system report\""
  exit 0
}

# Parse command-line options
while getopts "o:d:m:i:t:vrh" opt; do
  case $opt in
    o)
      output_file="$OPTARG"
      ;;
    d)
      output_dir="$OPTARG"
      ;;
    m)
      model="$OPTARG"
      ;;
    i)
      max_iterations="$OPTARG"
      ;;
    t)
      command_timeout="$OPTARG"
      ;;
    v)
      verbose=true
      ;;
    r)
      force_root=true
      ;;
    h)
      show_usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

# Check for required task argument
if [ $# -eq 0 ]; then
  echo "Error: You must provide a task description"
  echo "Usage: claude-agent.sh [-o output_file] \"your task\""
  exit 1
fi

task_description="$1"

# Get API key using the tulikieli credential manager
API_KEY=$(tulikieli get claude api_key)

if [ -z "$API_KEY" ]; then
    echo "Error: Could not retrieve Claude API key from tulikieli"
    echo "Make sure you've added it with: tulikieli add claude api_key"
    exit 1
fi

# Check for required tools
for cmd in jq curl mktemp timeout; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed but is required"
        if [ "$cmd" = "timeout" ]; then
            echo "Install coreutils: sudo pacman -S coreutils"
        else
            echo "Install $cmd: sudo pacman -S $cmd"
        fi
        exit 1
    fi
done

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# Create session ID based on timestamp
session_id=$(date +%Y%m%d_%H%M%S)
session_dir="$output_dir/$session_id"
mkdir -p "$session_dir"

# If output file is specified but without a path, put it in the session directory
if [ -n "$output_file" ] && [[ "$output_file" != */* ]]; then
    output_file="$session_dir/$output_file"
fi

# Initialize log files
command_log="$session_dir/commands.log"
output_log="$session_dir/output.log"
final_output="$session_dir/final_output.md"

# Initial log entries
echo "# Claude Agent Task: $task_description" > "$command_log"
echo "Started at $(date)" >> "$command_log"
echo "Session ID: $session_id" >> "$command_log"
echo "" >> "$command_log"

echo "# Claude Agent Session Output" > "$output_log"
echo "Task: $task_description" >> "$output_log"
echo "Started at $(date)" >> "$output_log"
echo "Session ID: $session_id" >> "$output_log"
echo "" >> "$output_log"

# Function to call Claude API
call_claude_api() {
    local prompt="$1"
    local temp_file=$(mktemp)
    
    # Create the request JSON
    jq -n --arg prompt "$prompt" --arg model "$model" '{
        model: $model,
        max_tokens: 4096,
        messages: [
            {
                role: "user",
                content: $prompt
            }
        ]
    }' > "$temp_file"
    
    if [ "$verbose" = true ]; then
        echo "Sending request to Claude API:"
        cat "$temp_file" | jq .
    fi
    
    # Call the API
    local response=$(curl -s https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d @"$temp_file")
    
    rm "$temp_file"
    
    # Check for errors in the API response
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "API Error:" >&2
        echo "$response" | jq -r '.error.message // .error' >&2
        return 1
    fi
    
    # Extract and return the text response
    echo "$response" | jq -r '.content[] | select(.type=="text") | .text'
}

# Function to validate command syntax
validate_command() {
    local command="$1"
    
    # Check for commands ending with a backslash (line continuation)
    if [[ "$command" =~ \\[[:space:]]*$ ]]; then
        echo "Command ends with a backslash (line continuation character) but has nothing to continue to."
        return 1
    fi
    
    # Check for incomplete shell loops/conditionals that might cause hanging
    if [[ "$command" =~ for[[:space:]].*[[:space:]]*$ || 
          "$command" =~ while[[:space:]].*[[:space:]]*$ || 
          "$command" =~ if[[:space:]].*[[:space:]]*$ ]]; then
        echo "Command appears to be incomplete. Missing proper loop/conditional closure."
        return 1
    fi
    
    # Check for unbalanced quotes
    local quote_count
    quote_count=$(echo "$command" | grep -o '"' | wc -l)
    if [ $((quote_count % 2)) -ne 0 ]; then
        echo "Command has unmatched double quotes."
        return 1
    fi
    
    local single_quote_count
    single_quote_count=$(echo "$command" | grep -o "'" | wc -l)
    if [ $((single_quote_count % 2)) -ne 0 ]; then
        echo "Command has unmatched single quotes."
        return 1
    fi
    
    # Check for unbalanced parentheses
    local paren_open=$(echo "$command" | grep -o "(" | wc -l)
    local paren_close=$(echo "$command" | grep -o ")" | wc -l)
    if [ $paren_open -ne $paren_close ]; then
        echo "Command has unbalanced parentheses."
        return 1
    fi
    
    # Check for unbalanced braces
    local brace_open=$(echo "$command" | grep -o "{" | wc -l)
    local brace_close=$(echo "$command" | grep -o "}" | wc -l)
    if [ $brace_open -ne $brace_close ]; then
        echo "Command has unbalanced braces."
        return 1
    fi
    
    # Very basic check for missing do/done in for loops
    if [[ "$command" =~ for[[:space:]] ]]; then
        if ! [[ "$command" =~ do ]] || ! [[ "$command" =~ done ]]; then
            echo "For loop is missing 'do' or 'done'."
            return 1
        fi
    fi
    
    # Check for missing fi in if statements
    if [[ "$command" =~ if[[:space:]] ]]; then
        if ! [[ "$command" =~ fi[[:space:]]*$ || "$command" =~ fi[[:space:]]*\; ]]; then
            echo "If statement is missing 'fi'."
            return 1
        fi
    fi
    
    return 0
}

# Function to execute a command safely
execute_command() {
    local command="$1"
    local requires_sudo="$2"
    local command_output_file="$3"
    
    # Log the command
    echo "## $(date +%H:%M:%S) Executing: $command" >> "$command_log"
    
    # Validate command syntax first
    if ! validate_command "$command"; then
        validation_error=$?
        validation_message=$(validate_command "$command" 2>&1)
        echo "Command validation failed: $validation_message" >> "$command_log"
        echo "ERROR: Invalid command syntax. $validation_message" > "$command_output_file"
        echo "Command not executed due to syntax validation failure: $validation_message"
        return 4  # Using 4 as exit code for "invalid syntax"
    fi
    
    # Extract the base command (before any pipes or redirects)
    local base_command=$(echo "$command" | awk '{print $1}')
    
    # Skip command existence check for built-in shell commands and compound commands
    local skip_check=false
    for builtin in cd echo printf pwd exit test [ source export unset alias eval exec; do
        if [ "$base_command" = "$builtin" ]; then
            skip_check=true
            break
        fi
    done
    
    # Also skip check if command contains &&, ||, |, or >
    if [[ "$command" == *"&&"* || "$command" == *"||"* || "$command" == *"|"* || "$command" == *">"* ]]; then
        skip_check=true
    fi
    
    # Check if the command exists (unless skipped)
    if [ "$skip_check" = "false" ] && ! command -v "$base_command" &> /dev/null; then
        echo "Command not found: $base_command" >> "$command_log"
        echo "ERROR: Command '$base_command' not found. Please install it before proceeding." > "$command_output_file"
        echo "Command not found: $base_command. Please install it first."
        
        # Provide installation suggestion for Arch Linux
        if [ -f "/etc/arch-release" ]; then
            echo "You might be able to install it with: sudo pacman -S $base_command" >> "$command_output_file"
            echo "You might be able to install it with: sudo pacman -S $base_command"
        fi
        
        return 2  # Using 2 as exit code for "command not found"
    fi
    
    # Check if command requires sudo and verify with user if needed
    if [ "$requires_sudo" = "true" ] && [ "$force_root" != "true" ]; then
        echo "This command requires root permissions: $command"
        read -p "Allow execution with sudo? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Command execution cancelled by user" >> "$command_log"
            echo "Command execution cancelled by user"
            echo "CANCELLED_BY_USER" > "$command_output_file"
            return 1
        fi
    fi
    
    # Add sudo if needed
    if [ "$requires_sudo" = "true" ]; then
        command="sudo $command"
    fi
    
    # Execute the command with timeout and capture its output
    echo "Executing: $command"
    # Use a temporary script file for more complex commands to avoid shell interpretation issues
    temp_script=$(mktemp)
    echo "#!/bin/bash" > "$temp_script"
    echo "$command" >> "$temp_script"
    chmod +x "$temp_script"
    
    timeout $command_timeout "$temp_script" > "$command_output_file" 2>&1
    command_exit_code=$?
    rm "$temp_script"
    
    # Handle timeout case
    if [ $command_exit_code -eq 124 ]; then
        echo "Command timed out after $command_timeout seconds" >> "$command_log"
        echo "ERROR: Command timed out after $command_timeout seconds. You can increase the timeout with the -t option." >> "$command_output_file"
        echo "Command timed out. You can increase the timeout with: claude-agent.sh -t 60 \"$task_description\""
        return 3  # Using 3 as exit code for "command timed out"
    elif [ $command_exit_code -ne 0 ]; then
        echo "Command failed with exit code $command_exit_code" >> "$command_log"
        echo "ERROR: Command failed with exit code $command_exit_code" >> "$command_output_file"
        return 1
    fi
    
    echo "Command completed successfully" >> "$command_log"
    return 0
}

# Main agent loop
iteration=0
commands_history=""
outputs_history=""
system_info=$(uname -a)

echo "🤖 Claude Agent started for task: '$task_description'"
echo "📁 Working in directory: $session_dir"

while [ $iteration -lt $max_iterations ]; do
    iteration=$((iteration + 1))
    echo "🔄 Iteration $iteration of $max_iterations"
    
    # Create the full prompt for Claude
    prompt="You are Claude Agent, a CLI assistant that helps Linux users accomplish tasks by executing shell commands.

TASK: $task_description

SYSTEM INFORMATION:
$system_info

PREVIOUS COMMANDS AND OUTPUTS:
$commands_history
$outputs_history

Your job is to decide what command to run next to accomplish the task. Follow these guidelines:
1. Provide exactly ONE command to run to make progress toward completing the task
2. For data collection or system information tasks, think step by step, collecting all relevant information
3. Specify if the command requires root privileges (sudo)
4. Be precise with command syntax for Arch Linux
5. Don't perform destructive actions - focus on reading system state not modifying it
6. Avoid overly complex commands with multiple operations (&&, ||, |) when possible - prefer simpler, focused commands
7. Don't use commands that may hang or take too long to complete without a good reason
8. For loops and complex commands must be COMPLETE with proper syntax (do/done, if/fi, etc.) - no partial commands
9. Keep commands simple and direct - ONE SINGLE LINE commands are strongly preferred
10. If the task is complete or you need no more commands, reply with 'TASK_COMPLETE' and a summary of what was accomplished

Respond in this structured format:
{
    \"requires_sudo\": true|false,
    \"command\": \"the exact command to execute\",
    \"explanation\": \"brief explanation of what this command does and why it's needed\"
}

Or if the task is complete:
{
    \"status\": \"TASK_COMPLETE\",
    \"summary\": \"summary of what was accomplished\",
    \"final_output\": \"markdown formatted final output that combines all the findings\"
}
"

    # Call Claude API
    response=$(call_claude_api "$prompt")
    if [ $? -ne 0 ]; then
        echo "❌ Error calling Claude API. Check your API key and internet connection."
        exit 1
    fi
    
    # Check if task is complete
    if echo "$response" | grep -q "TASK_COMPLETE"; then
        echo "✅ Task complete!"
        
        # Extract the final output and summary
        summary=$(echo "$response" | grep -o '"summary": *"[^"]*"' | cut -d'"' -f4)
        final_md=$(echo "$response" | sed -n '/"final_output": /,/^}/p' | sed 's/"final_output": //;s/^"//;s/",$//;s/\\n/\n/g;s/\\"/"/g;s/^}$//')
        
        # Clean up the output (remove leading/trailing quotes)
        final_md=$(echo "$final_md" | sed 's/^"//;s/"$//;s/\\"/"/g')
        
        # Save the final output
        echo "# Task Results: $task_description" > "$final_output"
        echo "" >> "$final_output"
        echo "$final_md" >> "$final_output"
        
        echo "Summary: $summary"
        echo "📝 Final output saved to: $final_output"
        
        # Copy to user-specified output file if provided
        if [ -n "$output_file" ]; then
            mkdir -p "$(dirname "$output_file")"
            cp "$final_output" "$output_file"
            echo "📄 Output also saved to: $output_file"
        fi
        
        break
    fi
    
    # Extract command info
    requires_sudo=$(echo "$response" | grep -o '"requires_sudo": *[^,}]*' | cut -d':' -f2 | tr -d ' ')
    command=$(echo "$response" | grep -o '"command": *"[^"]*"' | cut -d'"' -f4)
    explanation=$(echo "$response" | grep -o '"explanation": *"[^"]*"' | cut -d'"' -f4)
    
    # Skip iteration if we couldn't parse the command
    if [ -z "$command" ]; then
        echo "❌ Could not parse command from Claude's response. Skipping this iteration."
        commands_history="${commands_history}

ERROR: Failed to parse command from Claude's response in iteration $iteration.
Claude's response: 
$response

"
        continue
    fi
    
    # Show command and explanation
    echo "💻 Command: $command"
    echo "📌 Purpose: $explanation"
    
    # Generate a unique filename for this command's output
    command_output_file="$session_dir/cmd_${iteration}_output.txt"
    
    # Execute the command
    execute_command "$command" "$requires_sudo" "$command_output_file"
    command_status=$?
    
    # Append to history
    commands_history="${commands_history}

## Iteration $iteration
Command: $command
Requires sudo: $requires_sudo
Explanation: $explanation
"
    
    # Capture and display output summary
    output_size=$(wc -c < "$command_output_file")
    if [ $output_size -gt 1000 ]; then
        output_preview=$(head -n 20 "$command_output_file")
        echo "📄 Output (first 20 lines):"
        echo "$output_preview"
        echo "... (output truncated, full output in $command_output_file)"
    else
        output_preview=$(cat "$command_output_file")
        echo "📄 Output:"
        echo "$output_preview"
    fi
    
    # Add to outputs history
    if [ $command_status -eq 0 ]; then
        outputs_history="${outputs_history}

## Output of: $command
\`\`\`
$(cat "$command_output_file")
\`\`\`
"
    else
        # For command not found (status 2), provide installation suggestion
        if [ $command_status -eq 2 ]; then
            base_command=$(echo "$command" | awk '{print $1}')
            outputs_history="${outputs_history}

## Output of: $command (COMMAND NOT FOUND)
\`\`\`
Command '$base_command' not found. You may need to install it with:
sudo pacman -S $base_command
\`\`\`
"
        # For timeout (status 3), provide timeout information
        elif [ $command_status -eq 3 ]; then
            outputs_history="${outputs_history}

## Output of: $command (TIMED OUT)
\`\`\`
Command timed out after $command_timeout seconds. The command might be hanging or taking too long to complete.
You can increase the timeout with the -t option when running claude-agent.sh.
\`\`\`
"
        # For syntax validation failure (status 4)
        elif [ $command_status -eq 4 ]; then
            validation_message=$(cat "$command_output_file" | grep -o "ERROR: Invalid command syntax.*")
            outputs_history="${outputs_history}

## Output of: $command (INVALID SYNTAX)
\`\`\`
$validation_message
\`\`\`
"
        else
            outputs_history="${outputs_history}

## Output of: $command (FAILED or CANCELLED)
\`\`\`
$(cat "$command_output_file")
\`\`\`
"
        fi
    fi
    
    # Output the command and its result to the output log
    echo "## Command $iteration: $command" >> "$output_log"
    echo "" >> "$output_log"
    echo '```' >> "$output_log"
    cat "$command_output_file" >> "$output_log"
    echo '```' >> "$output_log"
    echo "" >> "$output_log"
    
    echo "---------------------------------------------------"
done

# Check if we reached max iterations without completing
if [ $iteration -ge $max_iterations ] && ! grep -q "TASK_COMPLETE" <<< "$response"; then
    echo "⚠️ Reached maximum iterations ($max_iterations) without completing the task."
    echo "🔍 Review the logs to see what was accomplished."
    
    # Generate a simple final output
    echo "# Task Results (Incomplete): $task_description" > "$final_output"
    echo "" >> "$final_output"
    echo "This task reached the maximum number of iterations ($max_iterations) without being marked as complete." >> "$final_output"
    echo "" >> "$final_output"
    echo "## Commands Executed" >> "$final_output"
    echo "" >> "$final_output"
    grep "^Command:" "$command_log" | sed 's/Command: /- /' >> "$final_output"
    echo "" >> "$final_output"
    echo "## Raw Output Log" >> "$final_output"
    echo "" >> "$final_output"
    echo "See the full output log at: $output_log" >> "$final_output"
    
    # Copy to user-specified output file if provided
    if [ -n "$output_file" ]; then
        mkdir -p "$(dirname "$output_file")"
        cp "$final_output" "$output_file"
        echo "📄 Output saved to: $output_file"
    fi
fi

echo "✨ Agent run complete. Session ID: $session_id"
echo "📂 All logs and outputs saved in: $session_dir"
