-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

-- local function is_dark_mode()
--   local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
--   if not handle then
--     return false
--   end
--
--   local result = handle:read("*a")
--   handle:close()
--
--   return result:match("Dark") ~= nil
-- end
--
-- local theme = is_dark_mode() and "onedark" or "one_light"

M.base46 = {
	theme = "catppuccin-latte",
      transparency = false,
      theme_toggle = { "catppuccin-latte", "catppuccin" },

	hl_override = {
		TelescopeMatching = { fg = "orange", bold = true, bg = "NONE" },
		TelescopeSelection = { bg = "one_bg3", bold = true },
	},
	hl_add = {
		TelescopeResultsComment = { fg = "light_grey" },
		RainbowDelimiterRed = { fg = "red" },
		RainbowDelimiterYellow = { fg = "yellow" },
		RainbowDelimiterBlue = { fg = "nord_blue" },
		RainbowDelimiterOrange = { fg = "orange" },
		RainbowDelimiterGreen = { fg = "green" },
		RainbowDelimiterViolet = { fg = "purple" },
		RainbowDelimiterCyan = { fg = "teal" },
	},
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
