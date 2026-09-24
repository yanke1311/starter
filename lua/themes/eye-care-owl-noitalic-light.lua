local M = vim.deepcopy(require "base46.themes.vscode_light")

M.base_30 = vim.tbl_extend("force", M.base_30, {
  white = "#403f53",
  darker_black = "#F6F6F6",
  black = "#FBFBFB",
  black2 = "#F0F0F0",
  one_bg = "#E0E7EA",
  one_bg2 = "#E0E0E0",
  one_bg3 = "#d3e8f8",
  grey = "#93A1A1",
  grey_fg = "#989fb1",
  grey_fg2 = "#90A7B2",
  light_grey = "#d9d9d9",
  red = "#E64D49",
  baby_pink = "#c96765",
  pink = "#994cc3",
  line = "#d9d9d9",
  green = "#2AA298",
  vibrant_green = "#0c969b",
  blue = "#4876d6",
  nord_blue = "#5ca7e4",
  yellow = "#daaa01",
  sun = "#aa0982",
  purple = "#994cc3",
  dark_purple = "#994cc3",
  teal = "#0c969b",
  orange = "#c96765",
  cyan = "#5f7e97",
  statusline_bg = "#F0F0F0",
  lightbg = "#E0E0E0",
  pmenu_bg = "#F0F0F0",
  folder_bg = "#403f53",
})

M.base_16 = vim.tbl_extend("force", M.base_16, {
  base00 = "#FBFBFB",
  base01 = "#F0F0F0",
  base02 = "#E0E0E0",
  base03 = "#d9d9d9",
  base04 = "#90A7B2",
  base05 = "#403f53",
  base06 = "#403f53",
  base07 = "#403f53",
  base08 = "#E64D49",
  base09 = "#c96765",
  base0A = "#daaa01",
  base0B = "#2AA298",
  base0C = "#0c969b",
  base0D = "#4876d6",
  base0E = "#994cc3",
  base0F = "#aa0982",
})

M.polish_hl = vim.tbl_deep_extend("force", M.polish_hl or {}, {
  syntax = {
    Comment = { fg = "#989fb1" },
    String = { fg = "#c96765" },
    Number = { fg = "#aa0982" },
    Function = { fg = "#994cc3" },
    Keyword = { fg = "#994cc3" },
    Type = { fg = "#994cc3" },
  },
  treesitter = {
    ["@comment"] = { fg = "#989fb1" },
    ["@string"] = { fg = "#c96765" },
    ["@number"] = { fg = "#aa0982" },
    ["@function"] = { fg = "#994cc3" },
    ["@function.call"] = { fg = "#0c969b" },
    ["@keyword"] = { fg = "#994cc3" },
    ["@type"] = { fg = "#403f53" },
    ["@variable"] = { fg = "#4876d6" },
    ["@variable.parameter"] = { fg = "#0c969b" },
    ["@property"] = { fg = "#4876d6" },
    ["@operator"] = { fg = "#0c969b" },
    ["@boolean"] = { fg = "#bc5454" },
    ["@constant.builtin.go"] = { fg = "#bc5454" },
  },
})

M.type = "light"

return require("base46").override_theme(M, "eye-care-owl-noitalic-light")
