local M = {}

local nxo = { "n", "x", "o" }

local function hop()
  return require "hop"
end

local function dir()
  return require("hop.hint").HintDirection
end

function M.setup()
  hop().setup {
    keys = "etovxqpdygfblzhckisuran",
  }
end

function M.char1(opts)
  hop().hint_char1(opts)
end

function M.char2(opts)
  hop().hint_char2(opts)
end

function M.words(opts)
  hop().hint_words(opts)
end

function M.lines(opts)
  hop().hint_lines_skip_whitespace(opts)
end

function M.pattern(pattern, opts)
  hop().hint_patterns(opts, pattern)
end

function M.search(forward)
  local pat = vim.fn.getreg "/"
  if pat == "" then
    vim.notify("No search pattern", vim.log.levels.WARN)
    return
  end
  local direction = forward and dir().AFTER_CURSOR or dir().BEFORE_CURSOR
  M.pattern(pat, { direction = direction })
end

function M.keys()
  local d = function()
    return dir()
  end

  local specs = {
    { "f", function() M.char1 { direction = d().AFTER_CURSOR, current_line_only = true } end, "Hop f" },
    { "F", function() M.char1 { direction = d().BEFORE_CURSOR, current_line_only = true } end, "Hop F" },
    { "t", function() M.char1 { direction = d().AFTER_CURSOR, current_line_only = true, hint_offset = -1 } end, "Hop t" },
    { "T", function() M.char1 { direction = d().BEFORE_CURSOR, current_line_only = true, hint_offset = 1 } end, "Hop T" },
    { "s", function() M.char2() end, "Hop s" },
    { "w", function() M.words { direction = d().AFTER_CURSOR } end, "Hop w" },
    { "b", function() M.words { direction = d().BEFORE_CURSOR } end, "Hop b" },
    { "W", function() M.words { direction = d().AFTER_CURSOR } end, "Hop W" },
    { "B", function() M.words { direction = d().BEFORE_CURSOR } end, "Hop B" },
    { "e", function() M.pattern([[\k\>]], { direction = d().AFTER_CURSOR }) end, "Hop e" },
    { "ge", function() M.pattern([[\k\>]], { direction = d().BEFORE_CURSOR }) end, "Hop ge" },
    { "E", function() M.pattern([[\S\ze\s\|$]], { direction = d().AFTER_CURSOR }) end, "Hop E" },
    { "gE", function() M.pattern([[\S\ze\s\|$]], { direction = d().BEFORE_CURSOR }) end, "Hop gE" },
    { "j", function() M.lines { direction = d().AFTER_CURSOR } end, "Hop j" },
    { "k", function() M.lines { direction = d().BEFORE_CURSOR } end, "Hop k" },
    { "n", function() M.search(true) end, "Hop n" },
    { "N", function() M.search(false) end, "Hop N" },
  }

  local keys = {
    {
      "<leader><leader>",
      mode = "n",
      function()
        M.char1 { multi_windows = true }
      end,
      desc = "Hop overwin f",
    },
    {
      "<leader><leader>",
      mode = { "x", "o" },
      function()
        M.char2()
      end,
      desc = "Hop s",
    },
  }

  for _, spec in ipairs(specs) do
    keys[#keys + 1] = {
      "<leader><leader>" .. spec[1],
      mode = nxo,
      spec[2],
      desc = spec[3],
    }
  end

  return keys
end

return M
