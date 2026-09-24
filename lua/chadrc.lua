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
	theme = "eye-care-owl-noitalic-light",
      transparency = false,
	  theme_toggle = { "eye-care-owl-noitalic-light", "catppuccin" },
	integrations = { "render-markdown" },

	hl_override = {
		CursorLine = { bg = "black2" },
		LspCodeLens = { fg = "#007ACC", underline = true },
		NvimTreeCursorLine = { bg = "#E0E7EA" },
		-- VS Code Light+ 的 editor.selectionBackground
		Visual = { bg = "#ADD6FF" },
		TelescopeMatching = { fg = "orange", bold = true, bg = "NONE" },
		TelescopeSelection = { bg = "one_bg3", bold = true },
	},
	hl_add = {
		-- 已 stage：绿。未 stage（含未跟踪）：红。
		NvimTreeGitStagedIcon = { fg = "#1FA84A" },
		NvimTreeGitFileStagedHL = { fg = "#1FA84A" },
		NvimTreeGitFolderStagedHL = { fg = "#1FA84A" },
		NvimTreeGitDirtyIcon = { fg = "#E64D49" },
		NvimTreeGitFileDirtyHL = { fg = "#E64D49" },
		NvimTreeGitFolderDirtyHL = { fg = "#E64D49" },
		NvimTreeGitNewIcon = { fg = "#E64D49" },
		NvimTreeGitFileNewHL = { fg = "#E64D49" },
		NvimTreeGitFolderNewHL = { fg = "#E64D49" },
		TelescopeResultsComment = { fg = "cyan" },
		TelescopeGrepPath = { fg = "cyan" },
		RainbowDelimiterRed = { fg = "red" },
		RainbowDelimiterYellow = { fg = "yellow" },
		RainbowDelimiterBlue = { fg = "nord_blue" },
		RainbowDelimiterOrange = { fg = "orange" },
		RainbowDelimiterGreen = { fg = "green" },
		RainbowDelimiterViolet = { fg = "purple" },
		RainbowDelimiterCyan = { fg = "teal" },
		RenderMarkdownCode = { bg = "one_bg2" },
		RenderMarkdownCodeBorder = { link = "RenderMarkdownCode" },
		RenderMarkdownCodeInline = { bg = "one_bg2", fg = "red" },
		RenderMarkdownBullet = { fg = "grey_fg" },
		RenderMarkdownH1 = { fg = "red", bold = true },
		RenderMarkdownH2 = { fg = "orange", bold = true },
		RenderMarkdownH3 = { fg = "yellow", bold = true },
		RenderMarkdownQuote1 = { fg = "nord_blue" },
		TreesitterContext = { bg = "one_bg" },
		TreesitterContextLineNumber = { bg = "one_bg", fg = "grey" },
		TreesitterContextSeparator = { fg = "light_grey", bg = "one_bg" },
	},
}

M.term = {
  float = { width = 0.9, height = 0.8, row = 0.1, col = 0.05 },
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
