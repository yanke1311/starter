-- Treesitter 彩虹括号；颜色在 chadrc hl_add，跟 Latte 对齐且偏饱和。

local M = {}

function M.setup()
  require("rainbow-delimiters.setup").setup {
    strategy = {
      [""] = "rainbow-delimiters.strategy.global",
    },
    query = {
      [""] = "rainbow-delimiters",
    },
    highlight = {
      "RainbowDelimiterRed",
      "RainbowDelimiterYellow",
      "RainbowDelimiterBlue",
      "RainbowDelimiterOrange",
      "RainbowDelimiterGreen",
      "RainbowDelimiterViolet",
      "RainbowDelimiterCyan",
    },
  }
end

return M
