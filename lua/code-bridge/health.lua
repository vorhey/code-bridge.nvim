local M = {}

M.check = function()
  vim.health.start("code-bridge.nvim")

  -- Check tmux availability
  vim.fn.system('command -v tmux 2>/dev/null')
  if vim.v.shell_error == 0 then
    vim.health.ok("tmux is available")
  else
    vim.health.warn("tmux not found in PATH", "Install tmux to use CodeBridgeTmux functionality")
  end

  -- Check claude CLI
  vim.fn.system('command -v claude 2>/dev/null')
  if vim.v.shell_error == 0 then
    vim.health.ok("claude CLI is available")

    -- Check claude CLI version
    local version_result = vim.fn.system('claude --version 2>/dev/null')
    if vim.v.shell_error == 0 then
      local version = vim.trim(version_result)
      vim.health.ok("claude version: " .. version)
    else
      vim.health.error("could not get claude version")
    end
  else
    vim.health.error("claude CLI not found in PATH",
      "Install claude CLI to use CodeBridgeQuery and CodeBridgeChat functionality")
  end

  -- Check clipboard functionality
  local test_string = "test"
  vim.fn.setreg('+', test_string)
  local clipboard_result = vim.fn.getreg('+')
  if clipboard_result == test_string then
    vim.health.ok("clipboard functionality works")
  else
    vim.health.warn("clipboard may not be working properly", "Check clipboard configuration")
  end
end

return M
