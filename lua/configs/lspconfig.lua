require("nvchad.configs.lspconfig").defaults()

local ok, blink = pcall(require, "blink.cmp")
if ok then
  vim.lsp.config("*", {
    capabilities = blink.get_lsp_capabilities(require("nvchad.configs.lspconfig").capabilities),
  })
end

local servers = { "html", "cssls", "rust_analyzer", "clangd", "gopls", "marksman", "pyright" }
vim.lsp.enable(servers)

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
