-- nvim-dap + cmake-tools(codelldb) / Python / Go。
-- F5 自动构建调试/继续，Shift-F5 停止；Ctrl-F5 自动构建运行。

local M = {}

-- 调试目标解释器与 Mason 自己运行 debugpy 的解释器是两回事。
function M.python_path()
  local suffix = vim.fn.has "win32" == 1 and "/Scripts/python.exe" or "/bin/python"
  for _, env in ipairs { "VIRTUAL_ENV", "CONDA_PREFIX" } do
    local root = vim.env[env]
    if root and vim.fn.executable(root .. suffix) == 1 then
      return root .. suffix
    end
  end
  for _, name in ipairs { ".venv", "venv" } do
    local path = vim.fn.getcwd() .. "/" .. name .. suffix
    if vim.fn.executable(path) == 1 then return path end
  end
  return vim.fn.exepath "python3" ~= "" and vim.fn.exepath "python3" or vim.fn.exepath "python"
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.WARN, { title = "Debug" })
end

local function find_root(marker)
  local start = vim.fn.expand "%:p:h"
  local found = vim.fs.find(marker, { upward = true, path = start })[1]
  return found and vim.fn.fnamemodify(found, ":h") or vim.fn.getcwd()
end

local function run_config(config)
  local dap = require "dap"
  config.cwd = config.cwd or vim.fn.getcwd()
  dap.run(config)
end

local function launch_json_for(filetype)
  local path = vim.fs.find(".vscode/launch.json", { upward = true, path = vim.fn.expand "%:p:h" })[1]
  if not path then
    return {}
  end
  local ok, configs = pcall(require("dap.ext.vscode").getconfigs, path)
  if not ok or type(configs) ~= "table" then
    return {}
  end
  local type_ft = {
    python = { "python" },
    debugpy = { "python" },
    go = { "go" },
    delve = { "go" },
    lldb = { "c", "cpp", "rust" },
    codelldb = { "c", "cpp", "rust" },
    cppdbg = { "c", "cpp" },
    rust = { "rust" },
  }
  local matched = {}
  for _, config in ipairs(configs) do
    local filetypes = type_ft[config.type] or { config.type }
    if vim.tbl_contains(filetypes, filetype) then
      matched[#matched + 1] = config
    end
  end
  return matched
end

local function run_launch_json(filetype)
  local configs = launch_json_for(filetype)
  if #configs == 0 then
    return false
  end
  if #configs == 1 then
    run_config(configs[1])
    return true
  end
  vim.ui.select(configs, {
    prompt = "launch.json",
    format_item = function(item)
      return item.name or item.type
    end,
  }, function(choice)
    if choice then
      run_config(choice)
    end
  end)
  return true
end

local function debug_python()
  run_config {
    type = "python",
    request = "launch",
    name = "Python: 当前文件",
    program = vim.fn.expand "%:p",
    cwd = find_root "pyproject.toml",
    pythonPath = M.python_path(),
    console = "integratedTerminal",
  }
end

local function debug_go()
  local test = vim.fn.expand("%:t"):match "_test%.go$"
  run_config {
    type = "delve",
    request = "launch",
    name = test and "Go: 当前包测试" or "Go: 当前包",
    mode = test and "test" or "debug",
    program = vim.fn.expand "%:p:h",
    cwd = find_root "go.mod",
  }
end

local function debug_rust()
  local file = vim.fn.expand "%:p"
  local manifest = vim.fs.find("Cargo.toml", { upward = true, path = vim.fn.fnamemodify(file, ":h") })[1]
  if not manifest then
    notify "当前文件不在 Cargo 工程里。"
    return
  end
  local root = vim.fn.fnamemodify(manifest, ":h")
  local meta_raw = vim.fn.system { "cargo", "metadata", "--no-deps", "--format-version", "1", "--manifest-path", manifest }
  if vim.v.shell_error ~= 0 then
    notify(vim.trim(meta_raw))
    return
  end
  local ok, meta = pcall(vim.json.decode, meta_raw)
  if not ok or type(meta) ~= "table" then
    notify "cargo metadata 解析失败。"
    return
  end

  local package
  local best = -1
  for _, pkg in ipairs(meta.packages or {}) do
    local dir = vim.fn.fnamemodify(pkg.manifest_path, ":h")
    if vim.startswith(file, dir) and #dir > best then
      package = pkg
      best = #dir
    end
  end
  if not package then
    notify "找不到当前文件所属的 Cargo 包。"
    return
  end

  local bins = {}
  for _, target in ipairs(package.targets or {}) do
    if vim.tbl_contains(target.kind, "bin") then
      bins[#bins + 1] = target
    end
  end
  local chosen
  for _, target in ipairs(bins) do
    if target.src_path == file then
      chosen = target
      break
    end
  end
  if not chosen then
    for _, target in ipairs(bins) do
      if target.name == package.name then
        chosen = target
        break
      end
    end
  end
  chosen = chosen or bins[1]
  if not chosen then
    notify "这个包没有可执行入口，无法直接调试。"
    return
  end

  notify("cargo build --bin " .. chosen.name, vim.log.levels.INFO)
  local build = vim.fn.system { "cargo", "build", "--bin", chosen.name, "--manifest-path", package.manifest_path }
  if vim.v.shell_error ~= 0 then
    notify(vim.trim(build))
    return
  end
  local exe = meta.target_directory .. "/debug/" .. chosen.name
  if vim.fn.has "win32" == 1 then
    exe = exe .. ".exe"
  end
  run_config {
    type = "codelldb",
    request = "launch",
    name = "Rust: " .. chosen.name,
    program = exe,
    cwd = vim.fn.fnamemodify(package.manifest_path, ":h"),
    stopOnEntry = false,
    args = {},
    console = "integratedTerminal",
  }
end

function M.start()
  local dap = require "dap"
  if dap.session() then return dap.continue() end
  -- CMake 项目优先自动构建调试；显式选 launch.json 请用 :DapNew。
  local cmake = require "cmake-tools"
  if cmake.is_cmake_project() then return M.cmake_debug() end

  local ft = vim.bo.filetype
  -- VS Code 已经写了 launch.json 时用它；没有才按语言自动启动。
  if run_launch_json(ft) then return end
  if ft == "python" then return debug_python() end
  if ft == "go" then return debug_go() end
  if ft == "rust" then return debug_rust() end
  dap.continue()
end

function M.cmake_debug()
  return require("configs.debug_cmake").start()
end

function M.run()
  return require("configs.debug_cmake").run()
end

function M.setup()
  local dap = require "dap"

  require("mason-nvim-dap").setup {
    ensure_installed = { "codelldb", "python", "delve" },
    automatic_installation = true,
    handlers = {
      python = function(config)
        for _, launch in ipairs(config.configurations or {}) do
          launch.pythonPath = M.python_path
          launch.cwd = "${workspaceFolder}"
        end
        require("mason-nvim-dap").default_setup(config)
        -- VS Code Python 扩展现用 type=debugpy；复用已装的同一个 adapter。
        dap.adapters.debugpy = dap.adapters.python
      end,
    },
  }

  require("nvim-dap-virtual-text").setup {
    commented = true,
  }

  -- 适配器断开或异常退出时，可能没有 terminated/exited 事件。
  -- 会话关闭后再清理，避免变量注释留在编辑窗口中。
  dap.listeners.on_session["clear-virtual-text"] = function(_, session)
    if not session then return end
    session.on_close["clear-virtual-text"] = function()
      vim.schedule(function()
        if next(dap.sessions()) then return end
        local virtual_text = require "nvim-dap-virtual-text/virtual_text"
        virtual_text.clear_virtual_text()
        virtual_text.clear_last_frames()
      end)
    end
  end

  vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
  vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "CursorLine" })

  local ok, view = pcall(require, "dap-view")
  if ok then
    dap.listeners.after.event_initialized["dap-view"] = function()
      view.open()
    end
    dap.listeners.before.event_terminated["dap-view"] = function()
      view.close()
    end
    dap.listeners.before.event_exited["dap-view"] = function()
      view.close()
    end
  end
end

function M.keys()
  local dap = function()
    return require "dap"
  end
  return {
    { "<F9>", function() dap().toggle_breakpoint() end, desc = "DAP 断点" },
    { "<F10>", function() dap().step_over() end, desc = "DAP 步过" },
    { "<F11>", function() dap().step_into() end, desc = "DAP 步入" },
    { "<F8>", function() dap().step_out() end, desc = "DAP 步出" },
    { "<F5>", M.start, desc = "Debug 启动/继续" },
    { "<S-F5>", function() dap().terminate() end, desc = "Debug 停止" },
    { "<C-F5>", M.run, mode = { "n", "i", "x", "t" }, desc = "CMake 构建并运行" },
    -- xterm 的 Ctrl-F5 编码 ESC[15;5~ 在本机被 terminfo 解码为 F29。
    { "<F29>", M.run, mode = { "n", "i", "x", "t" }, desc = "CMake 构建并运行（Ctrl-F5）" },
    { "<leader>dR", M.run, desc = "CMake 构建并运行（Ctrl-F5 备用）" },
    { "<leader>ds", M.start, desc = "Debug 启动/继续" },
    { "<leader>dr", function() dap().restart() end, desc = "Debug 重启" },
    { "<leader>de", function() require("dap.ui.widgets").hover() end, mode = { "n", "v" }, desc = "Debug 查看表达式" },
    { "<leader>dw", function() require("dap-view").add_expr() end, mode = { "n", "v" }, desc = "Debug 添加监视" },
    { "<leader>dB", function() vim.ui.input({ prompt = "断点条件: " }, function(value) if value and value ~= "" then dap().set_breakpoint(value) end end) end, desc = "Debug 条件断点" },
    { "<leader>db", function() dap().toggle_breakpoint() end, desc = "DAP 断点" },
    { "<leader>dc", M.start, desc = "DAP 继续/启动" },
    { "<leader>dC", M.cmake_debug, desc = "CMake 调试（检查配置）" },
    { "<leader>do", function() dap().step_over() end, desc = "DAP 步过" },
    { "<leader>di", function() dap().step_into() end, desc = "DAP 步入" },
    { "<leader>du", function() dap().step_out() end, desc = "DAP 步出" },
    { "<leader>dx", function() dap().terminate() end, desc = "DAP 结束" },
    {
      "<leader>dv",
      function()
        require("dap-view").toggle()
      end,
      desc = "DAP 面板",
    },
  }
end

return M
