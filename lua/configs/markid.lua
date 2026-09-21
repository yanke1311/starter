-- ColorMate 式同名标识符着色。
-- 上游 David-Kunz/markid 走 nvim-treesitter 旧 module API，0.12 main 无法挂上，这里用同一套 query + 名字哈希。

local M = {}

local ns = vim.api.nvim_create_namespace "markid"
local group = vim.api.nvim_create_augroup("markid", { clear = true })
local attached = {}
local name_hl = {}
local timer --- @type uv.uv_timer_t?

-- Latte 上偏饱和，扫变量比 markid 自带的 medium 灰粉更醒目
local colors = {
  "#D20F39",
  "#FE640B",
  "#DF8E1D",
  "#40A02B",
  "#179299",
  "#04A5E5",
  "#1E66F5",
  "#8839EF",
  "#EA76CB",
  "#E64553",
}

local queries = {
  default = "(identifier) @markid",
  c = [[
    (identifier) @markid
    (type_identifier) @markid
    (field_identifier) @markid
  ]],
  cpp = [[
    (identifier) @markid
    (type_identifier) @markid
    (field_identifier) @markid
    (namespace_identifier) @markid
  ]],
  python = "(identifier) @markid",
  go = [[
    (identifier) @markid
    (field_identifier) @markid
    (type_identifier) @markid
    (package_identifier) @markid
  ]],
  rust = [[
    (identifier) @markid
    (field_identifier) @markid
    (type_identifier) @markid
  ]],
}

local function hash_name(str)
  local h = 0
  for i = 1, #str do
    h = (h * 31 + str:byte(i)) % 2147483647
  end
  return h
end

local function hl_for(text)
  local cached = name_hl[text]
  if cached then
    return cached
  end
  local idx = (hash_name(text) % #colors) + 1
  local group_name = "Markid" .. idx
  vim.api.nvim_set_hl(0, group_name, { fg = colors[idx], default = true })
  name_hl[text] = group_name
  return group_name
end

local function parse_query(lang)
  local src = queries[lang] or queries.default
  local ok, query = pcall(vim.treesitter.query.parse, lang, src)
  if ok then
    return query
  end
  ok, query = pcall(vim.treesitter.query.parse, lang, queries.default)
  if ok then
    return query
  end
end

local function highlight_buf(buf)
  if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then
    return
  end
  local ft = vim.bo[buf].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft
  local query = parse_query(lang)
  if not query then
    return
  end
  local ok_parser, parser = pcall(vim.treesitter.get_parser, buf, lang)
  if not ok_parser or not parser then
    return
  end
  local trees = parser:parse()
  if not trees or not trees[1] then
    return
  end
  local root = trees[1]:root()
  local win = vim.fn.bufwinid(buf)
  local start_row, end_row = 0, -1
  if win ~= -1 then
    start_row = math.max(0, vim.fn.line("w0", win) - 80 - 1)
    end_row = vim.fn.line("w$", win) + 80
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, start_row, end_row == -1 and -1 or end_row)
  for id, node in query:iter_captures(root, buf, start_row, end_row) do
    if query.captures[id] == "markid" then
      local text = vim.treesitter.get_node_text(node, buf)
      if text and text ~= "" and not text:find "\n" then
        local sr, sc, er, ec = node:range()
        pcall(vim.hl.range, buf, ns, hl_for(text), { sr, sc }, { er, ec }, {
          priority = 120,
        })
      end
    end
  end
end

local function schedule(buf)
  if timer then
    timer:stop()
  else
    timer = vim.uv.new_timer()
  end
  timer:start(80, 0, vim.schedule_wrap(function()
    if vim.api.nvim_buf_is_valid(buf) then
      highlight_buf(buf)
    end
  end))
end

local function attach(buf)
  if attached[buf] then
    schedule(buf)
    return
  end
  local ft = vim.bo[buf].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft
  local ok_parser, parser = pcall(vim.treesitter.get_parser, buf, lang)
  if not ok_parser or not parser then
    return
  end
  attached[buf] = true
  parser:register_cbs {
    on_changedtree = function()
      schedule(buf)
    end,
  }
  schedule(buf)
end

function M.setup()
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter", "WinScrolled" }, {
    group = group,
    callback = function(args)
      local buf = args.buf
      if not buf or buf == 0 then
        buf = vim.api.nvim_get_current_buf()
      end
      if vim.bo[buf].buftype ~= "" then
        return
      end
      attach(buf)
    end,
  })
end

return M
