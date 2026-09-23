-- ColorMate 式同名标识符着色。
-- 上游 David-Kunz/markid 走 nvim-treesitter 旧 module API，0.12 main 无法挂上，这里用同一套 query + 名字哈希。

local M = {}

local ns = vim.api.nvim_create_namespace "markid"
local group = vim.api.nvim_create_augroup("markid", { clear = true })
local attached = {}
local name_hl = {}
local timer --- @type uv.uv_timer_t?

-- ColorMate 浅色默认：colormate.lightTheme.lighting=35, saturation=100
-- 哈希用 Colorcoder 的 CRC8 表 + HLS(crc/256, L, S)，不再改色相、不加抖动。

local CRC8 = {
  0x00, 0x07, 0x0E, 0x09, 0x1C, 0x1B, 0x12, 0x15, 0x38, 0x3F, 0x36, 0x31, 0x24, 0x23, 0x2A, 0x2D,
  0x70, 0x77, 0x7E, 0x79, 0x6C, 0x6B, 0x62, 0x65, 0x48, 0x4F, 0x46, 0x41, 0x54, 0x53, 0x5A, 0x5D,
  0xE0, 0xE7, 0xEE, 0xE9, 0xFC, 0xFB, 0xF2, 0xF5, 0xD8, 0xDF, 0xD6, 0xD1, 0xC4, 0xC3, 0xCA, 0xCD,
  0x90, 0x97, 0x9E, 0x99, 0x8C, 0x8B, 0x82, 0x85, 0xA8, 0xAF, 0xA6, 0xA1, 0xB4, 0xB3, 0xBA, 0xBD,
  0xC7, 0xC0, 0xC9, 0xCE, 0xDB, 0xDC, 0xD5, 0xD2, 0xFF, 0xF8, 0xF1, 0xF6, 0xE3, 0xE4, 0xED, 0xEA,
  0xB7, 0xB0, 0xB9, 0xBE, 0xAB, 0xAC, 0xA5, 0xA2, 0x8F, 0x88, 0x81, 0x86, 0x93, 0x94, 0x9D, 0x9A,
  0x27, 0x20, 0x29, 0x2E, 0x3B, 0x3C, 0x35, 0x32, 0x1F, 0x18, 0x11, 0x16, 0x03, 0x04, 0x0D, 0x0A,
  0x57, 0x50, 0x59, 0x5E, 0x4B, 0x4C, 0x45, 0x42, 0x6F, 0x68, 0x61, 0x66, 0x73, 0x74, 0x7D, 0x7A,
  0x89, 0x8E, 0x87, 0x80, 0x95, 0x92, 0x9B, 0x9C, 0xB1, 0xB6, 0xBF, 0xB8, 0xAD, 0xAA, 0xA3, 0xA4,
  0xF9, 0xFE, 0xF7, 0xF0, 0xE5, 0xE2, 0xEB, 0xEC, 0xC1, 0xC6, 0xCF, 0xC8, 0xDD, 0xDA, 0xD3, 0xD4,
  0x69, 0x6E, 0x67, 0x60, 0x75, 0x72, 0x7B, 0x7C, 0x51, 0x56, 0x5F, 0x58, 0x4D, 0x4A, 0x43, 0x44,
  0x19, 0x1E, 0x17, 0x10, 0x05, 0x02, 0x0B, 0x0C, 0x21, 0x26, 0x2F, 0x28, 0x3D, 0x3A, 0x33, 0x34,
  0x4E, 0x49, 0x40, 0x47, 0x52, 0x55, 0x5C, 0x5B, 0x76, 0x71, 0x78, 0x7F, 0x6A, 0x6D, 0x64, 0x63,
  0x3E, 0x39, 0x30, 0x37, 0x22, 0x25, 0x2C, 0x2B, 0x06, 0x01, 0x08, 0x0F, 0x1A, 0x1D, 0x14, 0x13,
  0xAE, 0xA9, 0xA0, 0xA7, 0xB2, 0xB5, 0xBC, 0xBB, 0x96, 0x91, 0x98, 0x9F, 0x8A, 0x8D, 0x84, 0x83,
  0xDE, 0xD9, 0xD0, 0xD7, 0xC2, 0xC5, 0xCC, 0xCB, 0xE6, 0xE1, 0xE8, 0xEF, 0xFA, 0xFD, 0xF4, 0xF3,
}

local LIGHT = 0.35
local SAT = 1.0

local function hsl_to_hex(h, s, l)
  h = h / 360
  local function channel(n)
    local k = (n + h * 12) % 12
    local a = s * math.min(l, 1 - l)
    local c = l - a * math.max(-1, math.min(k - 3, 9 - k, 1))
    return math.floor(c * 255 + 0.5)
  end
  return string.format("#%02X%02X%02X", channel(0), channel(8), channel(4))
end

local function crc8(str)
  local crc = 0
  for i = 1, #str do
    crc = CRC8[(crc ~ str:byte(i)) + 1]
  end
  return crc
end

local function color_for(text)
  -- CRC8 相邻（rules=243 / items=250）直接当色相会糊成一种粉。
  -- ×139（奇数、与 256 互质）把相邻哈希甩到色环两端，肉眼才能分开。
  local h = (crc8(text) * 139) % 256
  local hue = h * 360 / 256
  local sat = SAT
  local light = LIGHT
  -- 只搬 348°–18° 的血红 → 332°–350° 樱粉，带宽 30°→18°，不碰橙/玫红/紫。
  if hue >= 348 or hue < 18 then
    local t = hue >= 348 and (hue - 348) or (hue + 12)
    hue = 332 + t * 18 / 30
    sat = 0.85
    light = 0.50
  end
  return hsl_to_hex(hue, sat, light)
end

-- 关键字留给语法高亮。ColorMate 会给 variable/parameter/property 上色，不跳过 get/state。
local skip = {
  True = true,
  False = true,
  None = true,
  ["true"] = true,
  ["false"] = true,
  ["nil"] = true,
  null = true,
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
  python = [[
    (identifier) @markid
    (attribute attribute: (identifier) @markid)
  ]],
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

local function hl_for(text)
  local cached = name_hl[text]
  if cached then
    return cached
  end
  local crc = crc8(text)
  local group_name = "Markid" .. crc
  vim.api.nvim_set_hl(0, group_name, { fg = color_for(text) })
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
      if text and text ~= "" and not text:find "\n" and not skip[text] and #text > 1 then
        local sr, sc, er, ec = node:range()
        -- 必须压过 treesitter(100) 和 LSP semantic tokens(125)，否则方法名全是主题绿
        pcall(vim.hl.range, buf, ns, hl_for(text), { sr, sc }, { er, ec }, {
          priority = 200,
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
  name_hl = {}
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
