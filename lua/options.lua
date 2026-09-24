require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!
--
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.undofile = true
-- Ctrl-O / Ctrl-I 同时恢复跳转前的窗口滚动位置，避免光标贴在屏幕底部。
vim.opt.jumpoptions:append "view"
vim.opt.cursorlineopt = "both"
vim.opt.wrap = false
-- vim.opt.cursorline = true
-- vim.opt.cursorcolumn = true

local autocmd = vim.api.nvim_create_autocmd

autocmd("BufReadPost", {
  pattern = "*",
  callback = function()
    local line = vim.fn.line "'\""
    if
      line > 1
      and line <= vim.fn.line "$"
      and vim.bo.filetype ~= "gitcommit"
      and vim.fn.index({ "xxd", "gitrebase" }, vim.bo.filetype) == -1
    then
      vim.cmd 'normal! g`"'
    end
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  callback = function()
    local bufs = vim.t.bufs
    if #bufs == 1 and vim.api.nvim_buf_get_name(bufs[1]) == "" then
      vim.cmd "Nvdash"
    end
  end,
})

-- Quickfix 引用预览：跟随选择并高亮源码。
local qf_preview_ns = vim.api.nvim_create_namespace("qf_preview_ns")
local qf_preview_group = vim.api.nvim_create_augroup("qf_preview_follow", { clear = true })

local qf_state = {
  preview_win = nil,
  symbol = nil,
  qf_match_id = nil,
  preview_match_id = nil,
  preview_match_win = nil,
}

local function clear_all_qf_preview_highlight()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, qf_preview_ns, 0, -1)
    end
  end
end

local function get_qf_win()
  local info = vim.fn.getqflist({ winid = 0 })
  return info.winid ~= 0 and info.winid or nil
end

local function resolve_preview_win()
  local qf_win = get_qf_win()

  if qf_state.preview_win
    and vim.api.nvim_win_is_valid(qf_state.preview_win)
    and qf_state.preview_win ~= qf_win
  then
    return qf_state.preview_win
  end

  local alt_win = vim.fn.win_getid(vim.fn.winnr("#"))
  if alt_win ~= 0
    and vim.api.nvim_win_is_valid(alt_win)
    and alt_win ~= qf_win
  then
    qf_state.preview_win = alt_win
    return alt_win
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= qf_win then
      qf_state.preview_win = win
      return win
    end
  end

  return nil
end

local function get_symbol_from_win(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return nil
  end

  local ok, symbol = pcall(vim.api.nvim_win_call, win, function()
    return vim.fn.expand("<cword>")
  end)

  if ok and symbol and symbol ~= "" then
    return symbol
  end

  return nil
end

local function clear_symbol_matches()
  local qf_win = get_qf_win()

  if qf_state.qf_match_id and qf_win and vim.api.nvim_win_is_valid(qf_win) then
    pcall(vim.fn.matchdelete, qf_state.qf_match_id, qf_win)
  end
  qf_state.qf_match_id = nil

  if qf_state.preview_match_id
    and qf_state.preview_match_win
    and vim.api.nvim_win_is_valid(qf_state.preview_match_win)
  then
    pcall(vim.fn.matchdelete, qf_state.preview_match_id, qf_state.preview_match_win)
  end
  qf_state.preview_match_id = nil
  qf_state.preview_match_win = nil
end

local function add_symbol_match_to_win(win, symbol, hl)
  if not win or not vim.api.nvim_win_is_valid(win) or not symbol or symbol == "" then
    return nil
  end

  local pattern = [[\V\<]] .. vim.fn.escape(symbol, [[\]]) .. [[\>]]

  local ok, match_id = pcall(vim.api.nvim_win_call, win, function()
    return vim.fn.matchadd(hl or "Search", pattern, 20)
  end)

  if ok then
    return match_id
  end

  return nil
end

local function refresh_symbol_matches()
  clear_symbol_matches()

  local symbol = qf_state.symbol
  if not symbol or symbol == "" then
    return
  end

  local qf_win = get_qf_win()
  local preview_win = resolve_preview_win()

  qf_state.qf_match_id = add_symbol_match_to_win(qf_win, symbol, "Search")

  if preview_win then
    qf_state.preview_match_id = add_symbol_match_to_win(preview_win, symbol, "Search")
    qf_state.preview_match_win = preview_win
  end
end

local function get_current_qf_item()
  local info = vim.fn.getqflist({ items = 0 })
  local items = info.items or {}

  local line_nr = vim.fn.line(".")
  local item = items[line_nr]

  if not item or not item.bufnr or item.bufnr == 0 then
    return nil
  end

  return item
end

local function preview_qf_item()
  local item = get_current_qf_item()
  if not item then
    return
  end

  local preview_win = resolve_preview_win()
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    return
  end

  local bufnr = item.bufnr
  local lnum = (item.lnum and item.lnum > 0) and item.lnum or 1
  local col = (item.col and item.col > 0) and (item.col - 1) or 0

  vim.api.nvim_win_set_buf(preview_win, bufnr)
  vim.api.nvim_win_set_cursor(preview_win, { lnum, col })

  vim.api.nvim_win_call(preview_win, function()
    vim.cmd("normal! zz")
  end)

  clear_all_qf_preview_highlight()

  vim.api.nvim_buf_set_extmark(bufnr, qf_preview_ns, lnum - 1, 0, {
    line_hl_group = "Visual",
    priority = 200,
  })

  refresh_symbol_matches()
end

local function confirm_qf_item_and_close()
  local item = get_current_qf_item()
  if not item then
    return
  end

  local preview_win = resolve_preview_win()
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    return
  end

  vim.cmd("cclose")

  local lnum = (item.lnum and item.lnum > 0) and item.lnum or 1
  local col = (item.col and item.col > 0) and (item.col - 1) or 0

  vim.api.nvim_set_current_win(preview_win)
  vim.api.nvim_win_set_buf(preview_win, item.bufnr)
  vim.api.nvim_win_set_cursor(preview_win, { lnum, col })
  vim.cmd("normal! zz")

  clear_all_qf_preview_highlight()
  clear_symbol_matches()
end

-- lsp hover
vim.opt.updatetime = 500
vim.opt.mouse = "a"

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf

    vim.keymap.set("n", "K", vim.lsp.buf.hover, {
      buffer = bufnr,
      desc = "LSP Hover",
    })

    vim.keymap.set("n", "<leader>k", vim.lsp.buf.signature_help, {
      buffer = bufnr,
      desc = "Signature Help",
    })

    vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, {
      buffer = bufnr,
      desc = "Signature Help",
    })

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method "textDocument/codeLens" then
      vim.lsp.codelens.enable(true, { bufnr = bufnr })
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = qf_preview_group,
  pattern = "qf",
  callback = function(args)
    -- location list 也使用 qf 文件类型，保留它自己的窗口/列表行为。
    local wininfo = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    if wininfo and wininfo.loclist == 1 then return end
    local qf_buf = args.buf
    qf_state.preview_win = resolve_preview_win()
    qf_state.symbol = get_symbol_from_win(qf_state.preview_win)

    local opts = { buffer = qf_buf, silent = true, noremap = true, nowait = true }

    local function move_and_preview(key)
      return function()
        vim.cmd("normal! " .. key)
        preview_qf_item()
      end
    end

    vim.keymap.set("n", "j", move_and_preview("j"), opts)
    vim.keymap.set("n", "k", move_and_preview("k"), opts)
    vim.keymap.set("n", "<Down>", move_and_preview("j"), opts)
    vim.keymap.set("n", "<Up>", move_and_preview("k"), opts)

    vim.keymap.set("n", "<CR>", confirm_qf_item_and_close, opts)

    vim.keymap.set("n", "q", function()
      vim.cmd("cclose")
      clear_all_qf_preview_highlight()
      clear_symbol_matches()
    end, opts)

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(qf_buf) then
        preview_qf_item()
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("BufWinLeave", {
  group = qf_preview_group,
  pattern = "*",
  callback = function()
    -- BufWinLeave 触发时旧窗口尚在；下一轮再判断关闭状态。
    vim.schedule(function()
      if not get_qf_win() then
        clear_all_qf_preview_highlight()
        clear_symbol_matches()
      end
    end)
  end,
})
