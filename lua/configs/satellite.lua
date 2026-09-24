-- 右侧装饰滚动条：当前位置、诊断、gitsigns hunk、搜索。
-- 不是代码缩略图；左栏 gitsigns 仍负责行级标记。

return {
  current_only = true,
  winblend = 10,
  zindex = 40,
  excluded_filetypes = {
    "NvimTree",
    "oil",
    "TelescopePrompt",
    "TelescopeResults",
    "lazy",
    "mason",
    "nvdash",
    "nvcheatsheet",
    "terminal",
    "qf",
    "help",
    "man",
    "notify",
    "prompt",
    "Avante",
    "AvanteInput",
    "AvantePromptInput",
    "AvanteSelectedFiles",
    "dap-view",
    "dap-repl",
    "dapui_console",
    "dapui_watches",
  },
  handlers = {
    cursor = { enable = true },
    search = { enable = true },
    diagnostic = {
      enable = true,
      min_severity = vim.diagnostic.severity.WARN,
    },
    gitsigns = {
      enable = true,
      overlap = false,
      -- 使用实心块增强 git 标记的可见性。
      signs = {
        add = "█",
        change = "█",
        delete = "▄",
      },
    },
    marks = { enable = true, show_builtins = false },
    quickfix = { enable = true },
  },
}
