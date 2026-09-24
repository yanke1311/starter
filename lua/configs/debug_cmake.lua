local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.WARN, { title = "CMake" })
end

-- The plugin's selection APIs mutate this same config. Set it directly instead
-- of keeping a global vim.ui.select override alive across asynchronous jobs.
local function execute(debugging)
  local loaded, cmake = pcall(require, "cmake-tools")
  if not loaded then
    notify("请先加载 cmake-tools。")
    return
  end
  if not cmake.is_cmake_project() then
    notify("请切换到 CMake 项目根目录，或执行 :CMakeSelectCwd。")
    return
  end
  if debugging and type(cmake.debug) ~= "function" then
    notify("请先加载 nvim-dap 并启用 cmake-tools 的调试集成。")
    return
  end

  local config = cmake.get_config()
  local current_file = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
  local changed = false
  local configure_only = false
  local function assign(key, value)
    if config[key] ~= value then
      config[key] = value
      changed = true
    end
  end
  local use_preset = config.base_settings.use_preset and cmake.has_cmake_preset()
  if use_preset then
    local presets = require("cmake-tools.presets"):parse(config.cwd)
    if not presets then
      notify("CMake presets 解析失败。")
      return
    end
    local function choose(names, get, score)
      local best, best_score
      for _, name in ipairs(names) do
        local preset = get(name)
        if preset then
          local rank = score(preset)
          if rank and (not best_score or rank > best_score) then
            best, best_score = name, rank
          end
        end
      end
      return best
    end
    local function debug_score(preset)
      local kind = preset:get_build_type()
      return kind == "Debug" and 30 or kind == "RelWithDebInfo" and 20
        or preset.name:lower():find("debug", 1, true) and 10 or 0
    end
    local get_configure = function(name)
      return presets:get_configure_preset(name, { include_hidden = true })
    end
    local get_build = function(name)
      return presets:get_build_preset(name)
    end
    -- Preserve existing choices. A selected build preset owns its configure
    -- preset, just as cmake.select_build_preset does in the installed plugin.
    local build = config.build_preset and get_build(config.build_preset)
    if build and build:is_valid() then
      assign("configure_preset", build.configurePreset)
    else
      assign("build_preset", nil)
      local configure = config.configure_preset and get_configure(config.configure_preset)
      if not configure then
        assign("configure_preset", choose(presets:get_configure_preset_names(), get_configure, debug_score))
      end
      local name = choose(presets:get_build_preset_names({ include_disabled = false }), get_build, function(preset)
        if not preset:is_valid() or preset.configurePreset ~= config.configure_preset then
          return nil
        end
        return debug_score(preset)
      end)
      assign("build_preset", name)
      configure_only = name == nil
    end
    if not config.configure_preset then
      notify("没有可用的 CMake configure preset。")
      return
    end
    config:update_build_type()
  else
    if not config.build_type or (debugging and not config:validate_for_debugging():is_ok()) then
      local variants = require("cmake-tools.variants")
      local _, types = variants.get(require("cmake-tools.const").cmake_variants_message, config.cwd)
      local choice
      for _, variant in ipairs(types) do
        if variant.short == "Debug" then
          choice = variant
          break
        end
      end
      if not choice then
        for _, variant in ipairs(types) do
          if variants.debuggable(variant.short, config.cwd) then
            choice = variant
            break
          end
        end
      end
      if not choice then
        notify("没有可用的 Debug 配置。")
        return
      end
      assign("build_type", choice.short)
      config.variant = choice.kv
    end
    -- Match select_kit's config format without displaying its picker.
    if not config.kit then
      local kits = require("cmake-tools.kits").get(require("cmake-tools.const").cmake_kits_path, config.cwd)
      if kits and kits[1] then
        assign("kit", kits[1])
      end
    end
  end
  if debugging and not config:validate_for_debugging():is_ok() then
    notify("所选 preset 没有调试信息；请将该 preset 配置为 Debug/RelWithDebInfo。")
    return
  end

  local function launch()
    local result = cmake.get_launch_targets()
    if not result:is_ok() or not result.data or #result.data.targets == 0 then
      notify("当前 CMake 配置没有可执行目标。")
      return
    end
    local targets = result.data.targets
    local target
    local function valid(name)
      return name and vim.tbl_contains(targets, name)
    end
    do
      local current = current_file
      local models = config:get_code_model_info()
      for _, name in ipairs(targets) do
        for _, source in ipairs((models[name] or {}).sources or {}) do
          local path = source.path
          if not path:match("^/") and not path:match("^%a:[/\\]") then
            path = tostring(config.cwd) .. "/" .. path
          end
          if vim.fs.normalize(path) == current then
            target = name
            break
          end
        end
        if target then
          break
        end
      end
      if not target and valid(config.launch_target) then target = config.launch_target end
      for _, name in ipairs(type(config.build_target) == "table" and config.build_target or { config.build_target }) do
        if not target and valid(name) then
          target = name
        end
      end
      target = target or targets[1]
      config.launch_target = target
      if #targets > 1 then
        notify("自动选择可执行目标：" .. target .. "（:CMakeSelectLaunchTarget 可切换）", vim.log.levels.INFO)
      end
    end
    -- build() otherwise opens a build-preset picker for configure-only preset
    -- projects. Its synchronous entry accepts the already configured directory;
    -- restore preset mode immediately, before any asynchronous continuation.
    local preset_mode = config.base_settings.use_preset
    if configure_only then
      config.base_settings.use_preset = false
    end
    local ok, err = pcall(debugging and cmake.debug or cmake.run, { target = target, fargs = {} }, function(result)
      if result and not result:is_ok() then
        notify(tostring(result.message or "CMake 构建或启动失败。"))
      end
    end)
    config.base_settings.use_preset = preset_mode
    if not ok then
      notify(tostring(err))
    end
  end
  if changed or not config:has_build_directory() or not config:get_codemodel_targets():is_ok() then
    local called = false
    cmake.generate({ bang = false, fargs = {} }, function(result)
      if called then
        return
      end
      called = true
      if result and result:is_ok() then
        launch()
      else
        notify("CMake configure 失败，请查看 CMake 输出。")
      end
    end)
  else
    launch()
  end
end

function M.start()
  execute(true)
end

function M.run()
  execute(false)
end

return M
