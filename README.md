# code-bridge.nvim

Neovim ↔ tmux bridge for sending file context to a coding agent running in another tmux window.

This plugin focuses on a simple, reliable workflow:
- Send the current file (or a visual selection) as a context marker like `@path/to/file` or `@path/to/file#L10-20`.
- Send your git diffs (unstaged or staged) as context text.
- Choose the active provider (claude, codex, gemini, qwen) and target its tmux window by name.
- Stay in Neovim with optional success notifications.

<img src="code-bridge-demo.gif" alt="code-bridge-demo" width="400">

## Features

- Context from file or selection: `@relative/file` or `@relative/file#Lstart-Lend`.
- Git integration: send `git diff HEAD` or `git diff --cached` output.
- Tmux targeting by window name per provider.
- Popup provider selector: choose the active provider from a floating window.
- Optional bracketed paste support for providers that need it.
- Quiet by default: uses `vim.notify` for concise messages, no hit-enter prompts.

## Requirements

- Neovim 0.7+
- tmux (for sending context to an external agent)
- A provider running in a tmux window you name (e.g. `claude`, `codex`, `gemini`, `qwen`)

## Installation

Using lazy.nvim:

```lua
{
  "samir-roy/code-bridge.nvim",
  config = function()
    require("code-bridge").setup({
      provider = "claude", -- also the tmux window name
      notify_on_success = true,     -- show success toast for add commands
    })
  end,
}
```

## Usage

### Basic commands

- `:CodeBridgeAddContext`:
  - Sends current file or selection as context.
  - Shows a brief notification like: “added context to <provider>”.

- `:CodeBridgeDiff`:
  - Sends unstaged changes: output of `git diff HEAD`.

- `:CodeBridgeDiffStaged`:
  - Sends staged changes: output of `git diff --cached`.

- `:CodeBridgeUse`:
  - With `<provider>` arg: switch the active provider immediately.
  - Without args: open a popup picker that lists configured providers and the current one.

### Example keymaps (optional)

```lua
vim.keymap.set("n", "<leader>ct", ":CodeBridgeAddContext<CR>", { desc = "Send file or selection" })
vim.keymap.set("v", "<leader>ct", ":CodeBridgeAddContext<CR>", { desc = "Send selection" })
vim.keymap.set("n", "<leader>cd", ":CodeBridgeDiff<CR>",             { desc = "Send git diff" })
vim.keymap.set("n", "<leader>cD", ":CodeBridgeDiffStaged<CR>",       { desc = "Send staged diff" })
```

## Tmux Setup

Create a tmux window named after your provider and start the agent there, for example:

```bash
tmux new-session -d -s coding
tmux new-window -t coding -n claude
tmux send-keys -t coding:claude 'claude' Enter
```

Then in Neovim, `provider = "claude"` will target the tmux window named `claude`.

## Configuration Reference

- `provider` (string): active provider key; also the target tmux window name.
- `providers` (table of strings, optional): values shown in completion and popup selector. Defaults to `{"claude", "codex", "gemini", "qwen"}` plus the current provider.
- Target window name equals the `provider` value (e.g. `claude`).
- Bracketed paste is auto-enabled for known providers that need it; override with `bracketed_providers = { name = true/false }`.
- `notify_on_success` (boolean, default true): show success notifications for add commands.

## Health Check

Run `:checkhealth code-bridge.nvim` to verify tmux availability and basic environment.

## License

GNU GPL v2.0 — see LICENSE.

## Contributing

Issues and PRs are welcome. The scope is deliberately focused on sending context to an existing agent running in tmux.
