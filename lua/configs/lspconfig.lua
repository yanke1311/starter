require("nvchad.configs.lspconfig").defaults()

-- 同一行有多条诊断时，Neovim 只显示最后一条的文字。
-- 不反转时错误排在最后，行尾才会是红点和主错误，而不是后面的紫色 hint。
vim.diagnostic.config {
  severity_sort = true,
  virtual_text = {
    spacing = 2,
    prefix = function(_, i, total)
      if i == total then
        return "●"
      end
      return ""
    end,
  },
}

local ok, blink = pcall(require, "blink.cmp")
if ok then
  vim.lsp.config("*", {
    capabilities = blink.get_lsp_capabilities(require("nvchad.configs.lspconfig").capabilities),
  })
end

local servers = { "html", "cssls", "rust_analyzer", "clangd", "gopls", "marksman", "pyright" }

-- 必须用和当前 rustc/cargo 同一版的 rust-analyzer（rustup component）。
-- Mason 里那份更新，会给 cargo metadata 传 --lockfile-path，1.95 不认，
-- 工程加载失败，补全就只剩 snippet 和 keyword。
local function rust_analyzer_cmd()
  local cargo = vim.fn.expand "~/.cargo/bin/rust-analyzer"
  if vim.fn.executable(cargo) == 1 then
    local version = vim.fn.system { cargo, "--version" }
    if vim.v.shell_error == 0 and version:find "rust%-analyzer" then
      return { cargo }
    end
  end
  local mason = vim.fn.stdpath "data" .. "/mason/bin/rust-analyzer"
  if vim.fn.executable(mason) == 1 then
    return { mason }
  end
  return { "rust-analyzer" }
end

vim.lsp.config("rust_analyzer", { cmd = rust_analyzer_cmd() })
vim.lsp.enable(servers)

-- 行首 Run | Debug 是 rust-analyzer 的 CodeLens，光标放在那一行后按 ,cl。
-- 官方配置把 Run 做成阻塞的 vim.system，这里改成底部终端；Debug 走 F5 同一条路径。
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "rust_analyzer" then
      return
    end
    vim.lsp.commands["rust-analyzer.runSingle"] = function(command)
      local runnable = command.arguments[1]
      local cargo_args = vim.list_extend(vim.deepcopy(runnable.args.cargoArgs or {}), runnable.args.cargoExtraArgs or {})
      if runnable.args.executableArgs and #runnable.args.executableArgs > 0 then
        vim.list_extend(cargo_args, { "--" })
        vim.list_extend(cargo_args, runnable.args.executableArgs)
      end
      require("configs.dap").run_rust(cargo_args, runnable.args.cwd or runnable.args.workspaceRoot)
    end
    vim.lsp.commands["rust-analyzer.debugSingle"] = function()
      require("configs.dap").debug_rust()
    end
  end,
})

-- 不用 CursorHold：mousemoveevent（鼠标 hover）会不断进输入队列，Hold 永远触发不了。
-- 必须绑 WinEnter：关掉 gitsigns diff 分屏时经常只切窗口、不移动光标。
local doc_hl_timer = vim.uv.new_timer()
local doc_hl_gen = 0
local doc_hl_group = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })

local function schedule_document_highlight(args)
  local buf = args.buf
  pcall(vim.lsp.util.buf_clear_references, buf)
  doc_hl_timer:stop()
  doc_hl_gen = doc_hl_gen + 1
  local gen = doc_hl_gen
  local win = vim.api.nvim_get_current_win()
  doc_hl_timer:start(vim.o.updatetime, 0, vim.schedule_wrap(function()
    if gen ~= doc_hl_gen then
      return
    end
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
      return
    end
    if vim.api.nvim_win_get_buf(win) ~= buf or vim.api.nvim_get_current_win() ~= win then
      return
    end
    if vim.bo[buf].buftype ~= "" or vim.wo[win].diff then
      return
    end
    if vim.tbl_isempty(vim.lsp.get_clients { bufnr = buf, method = "textDocument/documentHighlight" }) then
      return
    end
    vim.lsp.buf.document_highlight()
  end))
end

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertLeave", "BufEnter", "WinEnter" }, {
  group = doc_hl_group,
  callback = schedule_document_highlight,
})

vim.api.nvim_create_autocmd("LspDetach", {
  group = doc_hl_group,
  callback = function(args)
    if vim.tbl_isempty(vim.lsp.get_clients { bufnr = args.buf, method = "textDocument/documentHighlight" }) then
      pcall(vim.lsp.util.buf_clear_references, args.buf)
    end
  end,
})

-- read :h vim.lsp.config for changing options of lsp servers
