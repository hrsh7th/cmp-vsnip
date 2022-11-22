local cmp = require('cmp')

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.is_available = function()
  return vim.g.loaded_vsnip
end

source.get_position_encoding_kind = function()
  return 'utf-8'
end

source.get_keyword_pattern = function()
  return '.'
end

source.complete = function(self, params, callback)
  local completion_items = {}

  for _, item in ipairs(vim.fn['vsnip#get_complete_items'](vim.api.nvim_get_current_buf())) do
    local completion_item = {}
    local user_data = vim.fn.json_decode(item.user_data)
    local text_edit = self:_get_text_edit(params, item.word, user_data.vsnip)
    if text_edit then
      completion_item.label = item.abbr
      completion_item.filterText = item.word
      completion_item.insertTextFormat = cmp.lsp.InsertTextFormat.Snippet
      completion_item.textEdit = text_edit
      completion_item.kind = cmp.lsp.CompletionItemKind.Snippet
      completion_item.data = {
        filetype = params.context.filetype,
        snippet = user_data.vsnip.snippet,
      }
      table.insert(completion_items, completion_item)
    end
  end

  callback(completion_items)
end

source.resolve = function(_, completion_item, callback)
  local documentation = {}
  table.insert(documentation, string.format('```%s', completion_item.data.filetype))
  for _, line in ipairs(vim.split(vim.fn['vsnip#to_string'](completion_item.data.snippet), '\n')) do
    table.insert(documentation, line)
  end
  table.insert(documentation, '```')

  completion_item.documentation = {
    kind = cmp.lsp.MarkupKind.Markdown,
    value = table.concat(documentation, '\n'),
  }
  callback(completion_item)
end

source._get_text_edit = function(_, params, prefix, snippet)
  local chars = vim.fn.split(vim.fn.escape(prefix, [[\/?]]), [[\zs]])
  local chars_pattern = [[\%(\V]] .. table.concat(chars, [[\m\|\V]]) .. [[\m\)]]
  local separator = chars[1]:match('%a') and [[\<]] or ''
  local whole_pattern = ([[%s\V%s\m%s*$]]):format(separator, chars[1], chars_pattern)
  local regex = vim.regex(whole_pattern)
  local s, e = regex:match_str(params.context.cursor_before_line)
  if not s then
    return
  end
  return {
    newText = table.concat(snippet.snippet, '\n'),
    range = {
      start = {
        line = params.context.cursor.line,
        character = s,
      },
      ['end'] = {
        line = params.context.cursor.line,
        character = e,
      },
    },
  }
end

return source
