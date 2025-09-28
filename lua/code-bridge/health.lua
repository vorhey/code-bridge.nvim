-- code-bridge neovim plugin
local M = {}

-- Configuration
local config = {
  provider = "claude",
  notify_on_success = true,
}

local function get_provider_name()
  return config.provider or "claude"
end

local function get_effective_tmux_idents()
  local window_name = get_provider_name()
  local bracketed_paste = (
    window_name == "gemini"
    or window_name == "qwen"
    or window_name == "opencode"
    or window_name == "groq"
  )
  return window_name, bracketed_paste
end

local function build_context(opts)
  local relative_file = vim.fn.expand("%")
  if relative_file ~= "" then
    if opts.range == 2 then
      return "@" .. relative_file .. "#L" .. opts.line1 .. "-" .. opts.line2
    else
      return "@" .. relative_file
    end
  end
  return ""
end

local function build_git_diff_context(staged_only)
  local cmd = staged_only and "git diff --cached" or "git diff HEAD"
  local diff_output = vim.fn.system(cmd .. " 2>/dev/null")

  if vim.v.shell_error ~= 0 or diff_output == "" then
    return nil, staged_only and "no staged changes" or "no git changes found"
  end

  local header = staged_only and "# Staged Changes (git diff --cached)\n" or "# Git Changes (git diff HEAD)\n"
  return header .. diff_output, nil
end

local function find_tmux_target()
  local win_name = get_effective_tmux_idents()
  vim.fn.system('tmux list-windows -F "#{window_name}" 2>/dev/null | grep -x ' .. win_name)
  if vim.v.shell_error == 0 then
    return win_name, nil
  else
    return nil, "no window named '" .. win_name .. "'"
  end
end

local function escape_for_tmux(message)
  local temp_file = vim.fn.tempname()
  local file = io.open(temp_file, "w")
  if file then
    file:write(message)
    file:close()
    return temp_file
  end
  return nil
end

local function send_to_tmux_target(message)
  local function check_shell_error(error_message)
    if vim.v.shell_error == 0 then
      return false
    end
    vim.notify(error_message, vim.log.levels.ERROR)
    return true
  end

  vim.fn.system('tmux display-message -p "#{session_name}" 2>/dev/null')
  if check_shell_error("no tmux session") then
    return false
  end

  local target, error_msg = find_tmux_target()
  if error_msg then
    vim.notify(error_msg, vim.log.levels.ERROR)
    return false
  end

  local _, bracketed_paste = get_effective_tmux_idents()

  local function paste_via_buffer(use_bracketed)
    local temp_file = escape_for_tmux(message .. "\n")
    if not temp_file then
      vim.notify("failed to create temp file", vim.log.levels.ERROR)
      return false
    end
    local paste_flag = use_bracketed and " -p" or ""
    local cmd =
      string.format('tmux load-buffer "%s" \\; paste-buffer -t %s%s \\; delete-buffer', temp_file, target, paste_flag)
    vim.fn.system(cmd)
    vim.fn.delete(temp_file)
    if check_shell_error("failed to send to " .. target) then
      return false
    end
    return true
  end

  local ok
  if bracketed_paste then
    ok = paste_via_buffer(true)
  else
    if message:find("\n") or message:find("['\"`$\\]") then
      ok = paste_via_buffer(false)
    else
      vim.fn.system("tmux send-keys -t " .. target .. " " .. vim.fn.shellescape(message) .. " Enter")
      ok = not check_shell_error("failed to send to " .. target)
    end
  end

  if not ok then
    return false
  end

  return true
end

local function send_to_tmux_wrapper(context, error_msg)
  if not context or context == "" then
    vim.notify(error_msg, vim.log.levels.WARN)
  else
    send_to_tmux_target(context)
  end
end

-- Send file or selection context and optionally notify
M.send_to_agent_tmux = function(opts)
  local context = build_context(opts or { range = 0 })
  if not context or context == "" then
    vim.notify("no file context available", vim.log.levels.WARN)
    return
  end

  local ok = send_to_tmux_target(context)

  if ok and config.notify_on_success then
    local provider_name = get_provider_name()
    vim.notify("added context to " .. tostring(provider_name), vim.log.levels.INFO)
  end
end

-- Send git diff to tmux
M.send_git_diff_to_tmux = function(staged_only)
  local context, error_msg = build_git_diff_context(staged_only)
  send_to_tmux_wrapper(context, error_msg)
end

-- Setup
M.setup = function(user_config)
  if user_config then
    config = vim.tbl_deep_extend("force", config, user_config)
  end

  -- Send current file or selected range and stay in Neovim
  vim.api.nvim_create_user_command("CodeBridgeAddContext", function(opts)
    M.send_to_agent_tmux(opts)
  end, { range = true })

  vim.api.nvim_create_user_command("CodeBridgeDiff", function()
    M.send_git_diff_to_tmux(false)
  end, {})
  vim.api.nvim_create_user_command("CodeBridgeDiffStaged", function()
    M.send_git_diff_to_tmux(true)
  end, {})

  vim.api.nvim_create_user_command("CodeBridgeUse", function(opts)
    local name = (opts.args or ""):gsub("%s+$", "")
    if name == "" then
      vim.notify("usage: CodeBridgeUse <provider>", vim.log.levels.WARN)
      return
    end
    config.provider = name
    vim.notify("CodeBridge provider set to " .. name, vim.log.levels.INFO)
  end, {
    nargs = 1,
    complete = function(ArgLead)
      local known = { "claude", "codex", "gemini", "qwen", "opencode", "groq" }
      local out = {}
      for _, k in ipairs(known) do
        if ArgLead == "" or k:sub(1, #ArgLead) == ArgLead then
          table.insert(out, k)
        end
      end
      return out
    end,
  })
end

return M
