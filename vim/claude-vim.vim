" claude-vim.vim - Claude AI assistant in Vim with whole file support

if exists('g:loaded_claude_vim')
  finish
endif
let g:loaded_claude_vim = 1

" Get API key from tulikieli credential manager
function! s:GetAPIKey()
  return trim(system('tulikieli get claude api_key'))
endfunction

" Function to send text to Claude API
function! s:AskClaude(text, prompt)
  let api_key = s:GetAPIKey()
  if empty(api_key)
    echom "Error: Could not retrieve API key from tulikieli"
    return "Error: Could not retrieve API key from tulikieli"
  endif
  
  let temp_file = tempname()
  let request_file = tempname()
  
  " Combine prompt and text if prompt is provided
  let full_content = empty(a:prompt) ? a:text : a:prompt . "\n\n```\n" . a:text . "\n```"
  
  " Create JSON request
  let request_json = '{"model":"claude-3-7-sonnet-20250219","max_tokens":4096,"messages":[{"role":"user","content":"' . escape(full_content, '"\') . '"}]}'
  call writefile([request_json], request_file)
  
  " Use curl with the file to avoid escaping issues
  let cmd = "curl -s https://api.anthropic.com/v1/messages " .
          \ "-H 'content-type: application/json' " .
          \ "-H 'x-api-key: " . api_key . "' " .
          \ "-H 'anthropic-version: 2023-06-01' " .
          \ "-d @" . request_file
  
  let response = system(cmd)
  
  " Clean up temp files
  call delete(request_file)
  
  " Debug - write response to a file for inspection
  call writefile([response], expand('~/claude_vim_response.json'))
  
  " Try to parse the response
  try
    let json_response = json_decode(response)
    
    " Extract content from response
    if has_key(json_response, 'content') && len(json_response.content) > 0
      let result = ""
      for item in json_response.content
        if has_key(item, 'type') && item.type == 'text' && has_key(item, 'text')
          let result .= item.text
        endif
      endfor
      return result
    else
      return "Error getting response from Claude: Invalid response format\n\nResponse: " . response
    endif
  catch
    return "Error parsing Claude's response: " . v:exception . "\n\nResponse: " . response
  endtry
endfunction

" Command to ask Claude about selected text with optional prompt
function! s:AskClaudeVisual() range
  let saved_reg = @"
  silent normal! gvy
  let selected_text = @"
  let @" = saved_reg
  
  " Ask for additional prompt
  let prompt = input('Ask Claude about this selection: ')
  
  let response = s:AskClaude(selected_text, prompt)
  
  " Create a new buffer with the response
  new
  setlocal buftype=nofile bufhidden=hide noswapfile
  call setline(1, split(response, "\n"))
  
  " Optional: syntax highlighting for markdown
  setlocal filetype=markdown
endfunction

" Command to ask Claude with input only
function! s:AskClaudePrompt()
  let prompt = input('Ask Claude: ')
  if prompt != ''
    let response = s:AskClaude(prompt, '')
    
    " Create a new buffer with the response
    new
    setlocal buftype=nofile bufhidden=hide noswapfile
    call setline(1, split(response, "\n"))
    
    " Optional: syntax highlighting for markdown
    setlocal filetype=markdown
  endif
endfunction

" Command to send the entire buffer to Claude
function! s:AskClaudeBuffer()
  " Get the entire buffer content
  let buffer_content = join(getline(1, '$'), "\n")
  
  " Get the file type and name for context
  let file_type = &filetype
  let file_name = expand('%:t')
  
  " Ask for a prompt
  let prompt = input('Ask Claude about this entire file: ')
  
  " Add file metadata to the prompt if available
  let full_prompt = prompt
  if !empty(file_name)
    let full_prompt .= "\n\nFile: " . file_name
  endif
  if !empty(file_type)
    let full_prompt .= "\nType: " . file_type
  endif
  
  let response = s:AskClaude(buffer_content, full_prompt)
  
  " Create a new buffer with the response
  new
  setlocal buftype=nofile bufhidden=hide noswapfile
  call setline(1, split(response, "\n"))
  
  " Optional: syntax highlighting for markdown
  setlocal filetype=markdown
endfunction

" Define commands
command! -range AskClaudeSelection <line1>,<line2>call s:AskClaudeVisual()
command! AskClaude call s:AskClaudePrompt()
command! AskClaudeBuffer call s:AskClaudeBuffer()

" Optional: Add mappings
nnoremap <leader>ca :AskClaude<CR>
vnoremap <leader>ca :AskClaudeSelection<CR>
nnoremap <leader>cf :AskClaudeBuffer<CR>
