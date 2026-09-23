vim.o.mousemoveevent = true

local DELAY_MS = 300
local ns = vim.api.nvim_create_namespace "lsp_mouse_hover"
local timer --- @type uv.uv_timer_t?
local hover_win --- @type integer?
local last_ident --- @type string?
local dismissed_ident --- @type string?
local request_id = 0

local function close_hover(buf)
  if hover_win and vim.api.nvim_win_is_valid(hover_win) then
    pcall(vim.api.nvim_win_close, hover_win, true)
  end
  hover_win = nil
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

local function hover_open()
  return hover_win and vim.api.nvim_win_is_valid(hover_win)
end

local function dismiss_hover()
  if not hover_open() then
    return false
  end
  dismissed_ident = last_ident
  request_id = request_id + 1
  if timer then
    timer:stop()
  end
  close_hover()
  return true
end

local function ident_at(buf, line, col)
  local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
  if not text or col < 1 then
    return ""
  end
  local before = text:sub(1, col)
  local after = text:sub(col + 1)
  return string.format(
    "%d:%d:%s%s",
    buf,
    line,
    vim.fn.matchstr(before, [[\k*$]]),
    vim.fn.matchstr(after, [[^\k*]])
  )
end

local function hover_contents(results)
  local contents = {}
  local nresults = 0
  for _, resp in pairs(results) do
    if resp.result and resp.result.contents then
      nresults = nresults + 1
    end
  end
  for client_id, resp in pairs(results) do
    local result = resp.result
    if result and result.contents then
      if nresults > 1 then
        local client = vim.lsp.get_client_by_id(client_id)
        contents[#contents + 1] = string.format("# %s", client and client.name or client_id)
      end
      vim.list_extend(contents, vim.lsp.util.convert_input_to_markdown_lines(result.contents))
      contents[#contents + 1] = "---"
    end
  end
  if contents[#contents] == "---" then
    contents[#contents] = nil
  end
  return contents
end

local function show_hover()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 or pos.line < 1 or pos.column < 1 then
    close_hover()
    last_ident = nil
    return
  end

  local cfg = vim.api.nvim_win_get_config(pos.winid)
  if cfg.relative ~= "" then
    return
  end

  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[buf].buftype ~= "" then
    close_hover(buf)
    last_ident = nil
    return
  end

  local clients = vim.lsp.get_clients { bufnr = buf, method = "textDocument/hover" }
  if #clients == 0 then
    close_hover(buf)
    last_ident = nil
    return
  end

  local ident = ident_at(buf, pos.line, pos.column)
  if ident == "" or ident:match ":%s*$" then
    close_hover(buf)
    last_ident = nil
    dismissed_ident = nil
    return
  end
  if ident == dismissed_ident then
    return
  end
  dismissed_ident = nil
  if ident == last_ident and hover_open() then
    return
  end

  last_ident = ident
  request_id = request_id + 1
  local this_request = request_id
  local line = pos.line
  local column = pos.column
  local winid = pos.winid

  vim.lsp.buf_request_all(buf, "textDocument/hover", function(client)
    local col = math.max(0, column - 1)
    local ok, character = pcall(vim.lsp.util.character_offset, buf, line - 1, col, client.offset_encoding)
    return {
      textDocument = vim.lsp.util.make_text_document_params(buf),
      position = { line = line - 1, character = ok and character or 0 },
    }
  end, function(results)
    if this_request ~= request_id then
      return
    end
    local now = vim.fn.getmousepos()
    if now.winid ~= winid or now.line ~= line then
      return
    end
    local contents = hover_contents(results)
    if vim.tbl_isempty(contents) then
      close_hover(buf)
      return
    end
    close_hover(buf)
    local _, win = vim.lsp.util.open_floating_preview(contents, "markdown", {
      border = "rounded",
      focus = false,
      focusable = false,
      focus_id = "lsp_mouse_hover",
      relative = "mouse",
      silent = true,
      close_events = { "InsertCharPre", "BufLeave", "WinScrolled" },
    })
    hover_win = win
  end)
end

local function schedule_hover()
  if vim.fn.mode() == "c" or vim.fn.pumvisible() == 1 then
    return
  end
  if timer then
    timer:stop()
  else
    timer = vim.uv.new_timer()
  end
  timer:start(DELAY_MS, 0, vim.schedule_wrap(show_hover))
end

vim.keymap.set({ "n", "i", "v" }, "<MouseMove>", schedule_hover, {
  silent = true,
  desc = "LSP mouse hover",
})

-- NvChad 随后会把 n 模式 <Esc> 绑成 noh，keymap 会被盖掉。
-- on_key 看实际按键，不依赖映射；Esc 仍会走 noh。
local key_ns = vim.api.nvim_create_namespace "lsp_mouse_hover_keys"
pcall(vim.on_key, nil, key_ns)
vim.on_key(function(_, typed)
  if typed == vim.keycode "<Esc>" then
    dismiss_hover()
  end
end, key_ns)

return {
  dismiss = dismiss_hover,
}
