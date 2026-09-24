-- GUI / Spotlight 启动的 nvim 拿不到 zshrc 里的 PATH。
-- Codex 在 ChatGPT.app，CodeBuddy 在 WorkBuddy.app，都不在默认 PATH 里。

local M = {}

local extra_dirs = {
  "/opt/homebrew/bin",
  "/opt/homebrew/sbin",
  "/usr/local/bin",
  vim.fn.expand "~/.local/bin",
  vim.fn.expand "~/.cargo/bin",
  vim.fn.expand "~/.bun/bin",
  vim.fn.expand "~/.mimocode/bin",
  vim.fn.expand "~/go/bin",
  vim.fn.expand "~/.npm-global/bin",
  "/Applications/ChatGPT.app/Contents/Resources",
  "/Applications/ChatGPT.app/Contents/Resources/cua_node/bin",
  "/Applications/WorkBuddy.app/Contents/Resources/app.asar.unpacked/cli/bin",
}

local function is_exe(path)
  return type(path) == "string" and path ~= "" and vim.fn.executable(path) == 1
end

local function prepend_path(dir)
  if type(dir) ~= "string" or dir == "" or vim.fn.isdirectory(dir) == 0 then
    return
  end
  local path = vim.env.PATH or ""
  for part in vim.gsplit(path, ":", { plain = true }) do
    if part == dir then
      return
    end
  end
  vim.env.PATH = dir .. (path ~= "" and (":" .. path) or "")
end

local function import_login_path()
  for _, cmd in ipairs {
    { "zsh", "-lic", "print -r -- $PATH" },
    { "bash", "-lc", "printf '%s\\n' \"$PATH\"" },
  } do
    local out = vim.fn.system(cmd)
    if vim.v.shell_error == 0 then
      local lines = vim.split(out or "", "\n", { trimempty = true })
      local login_path = lines[#lines]
      if login_path and login_path:find "/" then
        vim.env.PATH = login_path
        return
      end
    end
  end
end

local function is_windows_path(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  local lower = path:lower()
  return lower:match "%.exe$" or path:find "^/mnt/" or lower:find "^[a-z]:\\"
end

function M.setup()
  if not is_exe "codex" or not is_exe "codebuddy" or not is_exe "node" then
    import_login_path()
  end
  for _, dir in ipairs(extra_dirs) do
    prepend_path(dir)
  end
end

function M.node()
  local bin = vim.fn.exepath "node"
  if bin ~= "" then
    return bin
  end
  for _, path in ipairs {
    "/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node",
    vim.fn.expand "~/.bun/bin/bun",
    "/opt/homebrew/bin/node",
    "/usr/local/bin/node",
  } do
    if is_exe(path) then
      return path
    end
  end
  return ""
end

function M.codex()
  local bin = vim.fn.exepath "codex"
  if bin ~= "" then
    return bin
  end
  local bundled = "/Applications/ChatGPT.app/Contents/Resources/codex"
  if is_exe(bundled) then
    return bundled
  end
  return "codex"
end

function M.codebuddy()
  local bin = vim.fn.exepath "codebuddy"
  if bin ~= "" and not is_windows_path(bin) then
    return bin
  end
  for _, path in ipairs {
    vim.fn.expand "~/.local/bin/codebuddy",
    "/usr/local/bin/codebuddy",
    "/opt/homebrew/bin/codebuddy",
    "/Applications/WorkBuddy.app/Contents/Resources/app.asar.unpacked/cli/bin/codebuddy",
  } do
    if is_exe(path) and not is_windows_path(path) then
      return path
    end
  end
  if bin ~= "" then
    return bin
  end
  return "codebuddy"
end

function M.child_env(extra)
  local env = {}
  for key, value in pairs(vim.fn.environ()) do
    if type(key) == "string" and type(value) == "string" then
      env[key] = value
    end
  end
  env.PATH = vim.env.PATH
  if extra then
    for key, value in pairs(extra) do
      env[key] = value
    end
  end
  return env
end

local function codebuddy_needs_node(path)
  if path:match "%.m?js$" then
    return true
  end
  if is_windows_path(path) then
    return false
  end
  local f = io.open(path, "rb")
  if not f then
    return false
  end
  local head = f:read(256) or ""
  f:close()
  -- 原生二进制不要用 node 包一层（WSL 上会卡 ACP）
  if head:sub(1, 4) == "\127ELF" or head:sub(1, 4) == string.char(0xfe, 0xff, 0xff, 0xfe) then
    return false
  end
  if head:sub(1, 2) == "#!" then
    return head:find("node", 1, true) ~= nil
  end
  return false
end

function M.codebuddy_acp()
  local script = M.codebuddy()
  local resolved = vim.fn.exepath(script)
  if resolved ~= "" then
    script = resolved
  end
  local node = M.node()
  if node ~= "" and not is_windows_path(node) and codebuddy_needs_node(script) then
    return { command = node, args = { script, "--acp" } }
  end
  return { command = script, args = { "--acp" } }
end

return M
