-- Avante 输入框里打 `/` 时补全斜杠命令，而不是路径/片段。

local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:enabled()
  return vim.bo.filetype == "AvanteInput"
end

function source:get_trigger_characters()
  return { "/" }
end

function source:get_completions(ctx, callback)
  local line = ctx.line or ""
  if not line:match "^%s*/" then
    callback { items = {}, is_incomplete_forward = false, is_incomplete_backward = false }
    return
  end

  local ok, utils = pcall(require, "avante.utils")
  if not ok then
    callback { items = {}, is_incomplete_forward = false, is_incomplete_backward = false }
    return
  end

  local kind = require("blink.cmp.types").CompletionItemKind.Function
  local items = {}
  for _, cmd in ipairs(utils.get_commands()) do
    items[#items + 1] = {
      label = "/" .. cmd.name,
      kind = kind,
      detail = cmd.description or cmd.details or "",
      insertText = "/" .. cmd.name,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    }
  end
  callback { items = items, is_incomplete_forward = false, is_incomplete_backward = false }
end

return source
