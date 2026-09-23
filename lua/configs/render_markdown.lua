-- 侧栏 / 普通 md：素色标题 + 清晰的代码块、列表、引用（窄栏友好）

local M = {}

local avante_code = {
  -- 侧栏里 block 会贴左边、看起来更窄；full 拉满对话区
  width = "full",
  sign = false,
  border = "thin",
  language_icon = false,
  language_name = true,
  language_info = false,
  position = "left",
  right_pad = 1,
  inline = true,
  conceal_delimiters = true,
}

local avante_heading = {
  backgrounds = {},
  position = "inline",
  sign = false,
  width = "full",
  icons = {},
  border = false,
}

M.opts = {
  file_types = { "markdown", "Avante" },
  heading = {
    backgrounds = {},
    position = "inline",
    sign = false,
    width = "block",
    border = false,
  },
  code = {
    width = "block",
    min_width = 0,
    sign = false,
    border = "thin",
    language_icon = false,
    language_name = true,
    right_pad = 1,
    inline = true,
  },
  bullet = {
    icons = { "•", "◦", "▪", "▫" },
    right_pad = 1,
    highlight = "RenderMarkdownBullet",
  },
  quote = {
    enabled = true,
    icon = "▎",
    repeat_linebreak = false,
  },
  checkbox = {
    enabled = true,
  },
  pipe_table = {
    -- border 必须是字符数组；"thin" 不是合法值，会让表格渲染崩掉
    preset = "round",
    cell = "trimmed",
    wrap = true,
    border_virtual = true,
  },
  win_options = {
    conceallevel = { default = vim.o.conceallevel, rendered = 3 },
    concealcursor = { default = vim.o.concealcursor, rendered = "" },
    breakindent = { default = vim.o.breakindent, rendered = false },
  },
  -- 残缺表格会让官方 table renderer 抛错；包一层避免 Avante 刷屏报错。
  custom_handlers = {
    markdown = {
      extends = false,
      parse = function(ctx)
        local ok, marks = pcall(function()
          return require("render-markdown.handler.markdown").parse(ctx)
        end)
        if ok then
          return marks
        end
        return {}
      end,
    },
  },
  overrides = {
    filetype = {
      Avante = {
        heading = avante_heading,
        code = avante_code,
        pipe_table = {
          preset = "round",
          cell = "trimmed",
          wrap = true,
          border_virtual = true,
        },
        bullet = {
          icons = { "•", "◦", "▪" },
          right_pad = 1,
          highlight = "RenderMarkdownBullet",
        },
        quote = {
          icon = "▎",
        },
      },
    },
  },
}

-- 官方只画顶框、表头分隔、底框。Markdown 没有行间横线，窄栏里多行单元格会糊成一块。
function M.after_setup()
  local ok, Render = pcall(require, "render-markdown.render.markdown.table")
  if not ok or type(Render.border) ~= "function" or Render._row_rules then
    return
  end
  Render._row_rules = true
  local orig = Render.border
  function Render:border(wrapped)
    orig(self, wrapped)
    if not self.config.border_enabled or not self.data.layout.valid then
      return
    end
    local rows = self.data.rows
    -- rows = header + body...；表头下已有 delimiter，从第 3 行起在上方插 ├─┼─┤
    if #rows < 3 then
      return
    end
    local border = self.config.border
    local bar = border[11]
    local parts = {}
    for _, col in ipairs(self.data.cols) do
      parts[#parts + 1] = bar:rep(col.width)
    end
    local text = border[4] .. table.concat(parts, border[5]) .. border[6]
    local line = self:line():pad(self.data.layout.col):text(text, self.config.row)
    local virtual_line = self:indent():line(true):extend(line):get()
    for i = 3, #rows do
      local lines = wrapped[i]
      if lines then
        table.insert(lines, 1, virtual_line)
      else
        self.marks:add(self.config, "virtual_lines", rows[i].node.start_row, 0, {
          virt_lines = { virtual_line },
          virt_lines_above = true,
        })
      end
    end
  end
end

return M
