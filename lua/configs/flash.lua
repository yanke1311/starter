local M = {}

local nxo = { "n", "x", "o" }

local RE = {
  w = [[\(\<.\|^$\)]],
  W = [[\v(^|\s)\zs\S|^$]],
  e = [[\(.\>\|^$\)]],
  E = [[\v\S(\s|$)]],
  j = [[^\(\w\|\s*\zs\|$\)]],
}

local function jump(opts)
  require("flash").jump(opts)
end

function M.char(opts)
  opts = opts or {}
  jump {
    search = {
      mode = "exact",
      max_length = 1,
      forward = opts.forward,
      wrap = opts.wrap,
      multi_window = opts.multi_window or false,
    },
    label = { after = { 0, 0 }, before = false },
    jump = opts.jump,
  }
end

function M.pattern(pattern, opts)
  opts = opts or {}
  jump {
    pattern = pattern,
    search = {
      mode = "search",
      max_length = 0,
      forward = opts.forward,
      wrap = opts.wrap or false,
      multi_window = opts.multi_window or false,
    },
    label = { after = { 0, 0 }, before = false },
    jump = opts.jump,
  }
end

-- 词跳：先打目标词开头，筛完再出标签。避免 ,,w 给每个词都贴字母导致大量重复。
function M.word_prefix(opts)
  opts = opts or {}
  local prefix = opts.big and [[\v(^|\s)\zs]] or [[\<]]
  jump {
    search = {
      mode = function(str)
        if str == "" then
          return [[\v^$a]]
        end
        return prefix .. vim.fn.escape(str, [[\]])
      end,
      forward = opts.forward,
      wrap = opts.wrap or false,
      multi_window = opts.multi_window or false,
    },
    label = {
      after = { 0, 0 },
      before = false,
      min_pattern_length = 1,
    },
    jump = opts.jump,
  }
end

function M.search(opts)
  local pat = vim.fn.getreg "/"
  if pat == "" then
    vim.notify("No search pattern", vim.log.levels.WARN)
    return
  end
  M.pattern(pat, opts)
end

function M.keys()
  ---@type LazyKeysSpec[]
  local keys = {
    {
      "<leader><leader>",
      mode = "n",
      function()
        M.char { wrap = true, multi_window = true }
      end,
      desc = "EasyMotion overwin-f",
    },
    {
      "<leader><leader>",
      mode = { "x", "o" },
      function()
        M.char { wrap = true }
      end,
      desc = "EasyMotion s",
    },
    {
      "<C-s>",
      mode = "c",
      function()
        require("flash").toggle()
      end,
      desc = "Toggle Flash Search",
    },
  }

  local specs = {
    { "f", function() M.char { forward = true, wrap = false } end, "EasyMotion f" },
    { "F", function() M.char { forward = false, wrap = false } end, "EasyMotion F" },
    { "s", function() M.char { wrap = true } end, "EasyMotion s" },
    {
      "t",
      function()
        M.char { forward = true, wrap = false, jump = { offset = -1 } }
      end,
      "EasyMotion t",
    },
    {
      "T",
      function()
        M.char { forward = false, wrap = false, jump = { offset = 1 } }
      end,
      "EasyMotion T",
    },
    { "w", function() M.word_prefix { forward = true } end, "EasyMotion w" },
    { "b", function() M.word_prefix { forward = false } end, "EasyMotion b" },
    { "W", function() M.word_prefix { forward = true, big = true } end, "EasyMotion W" },
    { "B", function() M.word_prefix { forward = false, big = true } end, "EasyMotion B" },
    { "e", function() M.pattern(RE.e, { forward = true }) end, "EasyMotion e" },
    { "ge", function() M.pattern(RE.e, { forward = false }) end, "EasyMotion ge" },
    { "E", function() M.pattern(RE.E, { forward = true }) end, "EasyMotion E" },
    { "gE", function() M.pattern(RE.E, { forward = false }) end, "EasyMotion gE" },
    { "j", function() M.pattern(RE.j, { forward = true }) end, "EasyMotion j" },
    { "k", function() M.pattern(RE.j, { forward = false }) end, "EasyMotion k" },
    { "n", function() M.search { forward = true, wrap = true } end, "EasyMotion n" },
    { "N", function() M.search { forward = false, wrap = true } end, "EasyMotion N" },
    { "S", function() require("flash").treesitter() end, "Flash treesitter" },
    { "R", function() require("flash").treesitter_search() end, "Flash treesitter search" },
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
