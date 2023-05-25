local M = {}

M.namespace = vim.api.nvim_create_namespace("scalpelua")

-- replace first occurence of pattern after #position column to replacement
local function replace_in_line(pattern, replacement, lineno, position)
  local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
  local prefix = string.sub(line, 1, position - 1)
  local suffix = string.sub(line, position + string.len(pattern))
  local new_line = prefix .. replacement .. suffix
  vim.api.nvim_buf_set_lines(0, lineno - 1, lineno, false, {new_line})
end

-- replace all occurences of pattern in range between firstline and lastline to replacement
local function replace_in_range(pattern, replacement, firstline, lastline)
  for lineno = firstline, lastline do
    local position = 1
    repeat
      local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
      position = string.find(line, pattern, position, true)
      if position ~= nil then
        replace_in_line(pattern, replacement, lineno, position)
        position = position + 1
      end
    until position == nil
  end
end

-- highlight all occurences of pattern on #lineno line
-- return number of matches
local function highlight_in_line(pattern, lineno)
  local matches = 0
  local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
  local start, finish = 0, 0
  repeat
    start, finish = string.find(line, pattern, start, true)
    if start ~= nil then
      vim.api.nvim_buf_add_highlight(0, M.namespace, M.regular_pattern_hl, lineno - 1, start - 1, finish)
      matches = matches + 1
      start = start + 1
    end
  until start == nil
  return matches
end

-- highlight all occurences of pattern in range between firstline and lastline
-- return number of matches
function M.highlight_in_range(pattern, firstline, lastline)
  vim.api.nvim_buf_clear_namespace(0, M.namespace, firstline, lastline)
  local matches = 0
  for lineno = firstline, lastline do
    matches = matches + highlight_in_line(pattern, lineno)
  end
  return matches
end

function M.replace_all(pattern, replacement, firstline, lastline, startline, startcolumn, matches)
  local match = 0
  local replaced = 0
  local lineno = startline
  local start = startcolumn
  local finish = 0
  repeat
    repeat
      local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
      start, finish = string.find(line, pattern, start, true)
      if start ~= nil then
        match = match + 1

        vim.api.nvim_win_set_cursor(0, {lineno, start})
        if M.minimap_enabled then
          MiniMap.update_map_lines()
          MiniMap.update_map_scrollbar()
          MiniMap.update_map_integrations()
        end
        vim.api.nvim_buf_add_highlight(0, M.namespace, M.current_pattern_hl, lineno - 1, start - 1, finish)
        vim.cmd('redraw')

        local input
        repeat
          print(string.format("[%s/%s] replace with %s (y/n/a/q/l)?", match, matches, replacement))
          input = vim.fn.getcharstr()
          vim.cmd('redraw')
        until string.find(input, '^[ynaql]$')

        if input == 'y' then
          replace_in_line(pattern, replacement, lineno, start)
          highlight_in_line(pattern, lineno)
          replaced = replaced + 1
          start = start + #replacement
          if M.minimap_enabled then
            MiniMap.update_map_integrations()
          end
        elseif input == 'n' then
          vim.api.nvim_buf_clear_namespace(0, M.namespace, lineno - 1, lineno)
          highlight_in_line(pattern, lineno)
          start = start + #pattern
        elseif input == 'a' then
          replace_in_range(pattern, replacement, firstline, lastline)
          vim.api.nvim_win_set_cursor(0, {startline, startcolumn})
          return matches
        elseif input == 'l' then
          replace_in_line(pattern, replacement, lineno, start)
          highlight_in_line(pattern, lineno)
          replaced = replaced + 1
          return replaced
        elseif input == 'q' or input == string.char(27) then
          return replaced
        end
      end
    until start == nil or match == matches
    -- wrap around the end of file
    if lineno ~= lastline then
      lineno = lineno + 1
    else
      lineno = firstline
    end
  until match == matches
  return replaced
end

function M.setup(opts)
  M.minimap_enabled = opts.minimap_enabled
  M.regular_pattern_hl = opts.highlighting.regular_search_pattern
  M.current_pattern_hl = opts.highlighting.current_search_pattern
end

return M
