**This repo is supposed to be used as config by NvChad users!**

- The main nvchad repo (NvChad/NvChad) is used as a plugin by this repo.
- So you just import its modules , like `require "nvchad.options" , require "nvchad.mappings"`
- So you can delete the .git from this repo ( when you clone it locally ) or fork it :)

## 调试（现有安装版本，无插件升级）

- `F5` / `,dc` / `,ds`：已有会话则继续；CMake 项目优先自动配置、构建、调试；其他项目交给 DAP 选择 launch.json / 语言配置。
- `Shift-F5` / `,dx`：停止；`Ctrl-F5` / `,dR`：CMake 自动配置、构建并直接运行（普通、插入、可视、终端模式，兼容终端解码为 F29）；`,dC`：强制走 CMake 自动调试。
- `F9`：断点；`,dB`：条件断点；`F10`：步过；`F11`：步入；`F8`：步出；`,dr`：重启。
- `,dv`：调试面板；`,de`：查看表达式；`,dw`：添加监视。
- 面板保留插件原生可点击图标；不添加自定义按钮文字。面板内 `S` 变量、`T` 线程/栈帧、`W` 监视、`B` 断点、`R` REPL；回车或双击展开/跳转，`g?` 查看当前页帮助。
- 程序输入在调试终端中进行；REPL 用于表达式/调试器命令。`Ctrl-反引号` 保持 NvChad 独立终端开关，和 DAP 终端不是同一个实例。
- CMake 自动入口负责选择调试配置与可执行目标；多个目标优先匹配当前源码，其次已有目标。只在用户断点暂停，不额外停 main。构建失败会停止启动，而非运行旧产物。
- 多文件程序会随断点/单步自动打开对应源码并跳转；源码需加入 CMake 目标且以 Debug 配置构建。
- Python 默认配置运行当前文件，动态寻找激活环境、项目 `.venv` / `venv`、系统 Python。模块、参数、环境变量建议放项目 launch.json。

### 与 VS Code 共用配置

当前 nvim-dap 自动读取当前工作目录下 `.vscode/launch.json`，无需额外调用 `load_launchjs`。
C++ 使用 VS Code 的 CodeLLDB 扩展与 `type: "codelldb"`，Python 使用 `type: "debugpy"`（已注册别名）。
共用配置使用静态相对路径和 `${workspaceFolder}`，避免依赖 VS Code 专属的 `${command:cmake.launchTargetPath}` / `preLaunchTask`；nvim-dap 不负责执行 VS Code tasks。
CodeLLDB 使用 `terminal: "integrated"`；debugpy 使用 `console: "integratedTerminal"`，两者字段属于各自适配器，和终端快捷键无关。

例如（相同 Linux/WSL 工作区，按实际构建产物与虚拟环境调整路径）：

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "C++ shared",
      "type": "codelldb",
      "request": "launch",
      "program": "${workspaceFolder}/out/Debug/app",
      "cwd": "${workspaceFolder}",
      "terminal": "integrated"
    },
    {
      "name": "Python shared",
      "type": "debugpy",
      "request": "launch",
      "program": "${file}",
      "cwd": "${workspaceFolder}",
      "python": "${workspaceFolder}/.venv/bin/python",
      "console": "integratedTerminal",
      "args": []
    }
  ]
}
```

CMake 项目 `F5` 优先自动构建调试；希望显式使用共用 launch.json 时执行 `:DapNew`，这条路径需先自行构建 C++。Ctrl-F5 若被终端/桌面拦截，可用 `,dR` 调用同一运行入口；使用 `:lua print(vim.fn.keytrans(vim.fn.getcharstr()))` 后按 Ctrl-F5 检查实际收到的按键。
VS Code 若在原生 Windows、Neovim 在 WSL，属于不同运行环境，应使用 `windows` / `linux` 配置覆盖各自的程序和解释器路径，或两端都在 WSL 运行。

### 插件版本

补充 lazy-lock 仅记录已安装 commit，不等于升级，也不会在下次启动自动按新锁文件更新已有插件。
现有环境直接重启 Neovim 即可，不需要执行 Lazy update/sync/restore。
`Lazy update` 会更新插件；`Lazy sync` 包含更新；`Lazy restore` 将已安装插件还原到锁定 commit（不会按锁文件未列出就删除配置中仍声明的插件）。

# Credits

1) Lazyvim starter https://github.com/LazyVim/starter as nvchad's starter was inspired by Lazyvim's . It made a lot of things easier!
