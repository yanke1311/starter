local M = {}

-- VS Code extensions/git/package.json: gitDecoration.*ResourceForeground.
M.colors = {
  light = { added = "#587c0c", modified = "#B87900", deleted = "#ad0707", renamed = "#007100", untracked = "#007100", ignored = "#8e8e90", conflict = "#ad0707" },
  dark = { added = "#81b88b", modified = "#e2c08d", deleted = "#c74e39", renamed = "#73c991", untracked = "#73c991", ignored = "#8c8c8c", conflict = "#e4676b" },
}

local badges = { added = "A", modified = "M", deleted = "D", renamed = "R", untracked = "U", conflict = "!" }
local priorities = { conflict = 1, deleted = 2, modified = 3, renamed = 4, added = 5, untracked = 6, ignored = 7 }
local conflicts = { DD = true, AU = true, UD = true, UA = true, DU = true, AA = true, UU = true }

function M.classify(xy)
  if conflicts[xy] then return "conflict" end
  if xy == "??" then return "untracked" end
  if xy == "!!" then return "ignored" end
  -- Working-tree changes override index changes, as in VS Code's Explorer.
  if xy:sub(2, 2) == "D" then return "deleted" end
  if xy:sub(2, 2) == "M" or xy:sub(2, 2) == "T" then return "modified" end
  if xy:find("R", 1, true) then return "renamed" end
  if xy:find("A", 1, true) or xy:find("C", 1, true) then return "added" end
  if xy:find("D", 1, true) then return "deleted" end
  if xy == "dirty" or xy:find("M", 1, true) or xy:find("T", 1, true) then return "modified" end
end

function M.status(node)
  local git = node.git_status or {}
  local best
  local function consider(xy)
    local status = M.classify(xy)
    if status and (not best or priorities[status] < priorities[best]) then best = status end
  end
  if git.file then consider(git.file) end
  for _, entries in pairs(git.dir or {}) do
    for _, xy in ipairs(entries) do consider(xy) end
  end
  return best
end

function M.decorator()
  local Decorator = require("nvim-tree.api").Decorator:extend()
  function Decorator:new()
    self.enabled = true
    self.highlight_range = "name"
    self.icon_placement = "after"
    for status, color in pairs(M.colors[vim.o.background == "dark" and "dark" or "light"]) do
      vim.api.nvim_set_hl(0, "NvimTreeVSCode" .. status, { fg = color })
    end
  end
  function Decorator:highlight_group(node)
    local status = M.status(node)
    return status and "NvimTreeVSCode" .. status or nil
  end
  function Decorator:icons(node)
    local status = M.status(node)
    if status and badges[status] then
      return { { str = badges[status], hl = { "NvimTreeVSCode" .. status } } }
    end
  end
  return Decorator
end

return M
