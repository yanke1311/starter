-- nwiizo/codex.nvim：0.12 原生接 Codex CLI。
-- 快捷键避开 CodeBuddy（,cc / Cmd+I）和 flash 的 f/t/s。

local M = {}

function M.opts()
  local hide = { "<C-q>" }
  if vim.fn.has "mac" == 1 then
    hide[#hide + 1] = "<D-l>"
  else
    hide[#hide + 1] = "<C-A-l>"
    hide[#hide + 1] = "<M-C-l>"
  end
  return {
    backend = "terminal",
    cmd = { require("configs.cli_path").codex() },
    cwd = "root",
    focus_after_send = false,
    terminal = {
      layout = "split",
      split_side = "right",
      split_width_percentage = 0.35,
      auto_insert = true,
      -- 终端模式下这些键能藏起面板，不会把按键发给 Codex TUI
      hide_keys = hide,
    },
    selection = {
      enabled = true,
      hint = true,
      keymaps = { ask = "<leader>ca", edit = "<leader>ce" },
    },
  }
end

function M.keys()
  local keys = {
    { "<leader>cx", "<cmd>CodexFocus<cr>", mode = { "n", "v" }, desc = "Codex 侧边栏" },
    { "<leader>cq", "<cmd>CodexClose<cr>", desc = "关闭 Codex 面板" },
    { "<leader>ca", "<cmd>CodexAsk<cr>", mode = { "n", "v" }, desc = "Codex 提问" },
    { "<leader>ce", "<cmd>CodexEdit<cr>", mode = "v", desc = "Codex 改选区" },
    { "<leader>cs", ":<C-U>CodexSendVisual<CR>", mode = "v", desc = "Codex 发送选区" },
    { "<leader>cb", "<cmd>CodexAdd<cr>", desc = "Codex 添加当前文件" },
  }
  if vim.fn.has "mac" == 1 then
    keys[#keys + 1] = { "<D-l>", "<cmd>CodexFocus<cr>", mode = { "n", "v", "i", "t" }, desc = "Codex 侧边栏" }
  else
    keys[#keys + 1] = { "<C-A-l>", "<cmd>CodexFocus<cr>", mode = { "n", "v", "i", "t" }, desc = "Codex 侧边栏" }
    keys[#keys + 1] = { "<M-C-l>", "<cmd>CodexFocus<cr>", mode = { "n", "v", "i", "t" }, desc = "Codex 侧边栏" }
  end
  return keys
end

return M
