local M = {}

M.highlighting_ns = vim.api.nvim_create_namespace("scalpelua_hl")

-- replace first occurrence of pattern after #position column to
-- replacement on number lineno line
-- lineno is one-based
-- position is one-based
local function replace_in_line(pattern, replacement, lineno, position)
  local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
  local prefix = string.sub(line, 1, position - 1)
  local suffix = string.sub(line, position + string.len(pattern))
  local new_line = prefix .. replacement .. suffix
  vim.api.nvim_buf_set_lines(0, lineno - 1, lineno, false, {new_line})
end

-- replace all occurrences of pattern to replacement
-- inside given range between start and finish
-- range is list {firstline, lastline}
-- start is list {line, column}
-- finish is list {line, column}
-- lines and columns are one-based
local function replace_in_range(pattern, replacement, range, start, finish)
  -- We have two situations:
  -- 1. startline < finishline:
  --    * go from {startline, startcolumn} to {finishline, finishcolumn}
  --
  --    ---------------------------------------------------------
  --    #########################################################
  --    #########################################################
  --    #####################################[S]*****************
  --    ******** region where we need ***************************
  --    ************************to replace pattern **************
  --    ************[F]##########################################
  --    #########################################################
  --    ---------------------------------------------------------
  --
  -- 2. startline > finishline:
  --    * go from {startline, startcolumn} to the end of the range
  --    * set wrapped = true and jump to the start of the range
  --    * go from the start of the range to {finishline, finishcolumn}
  --
  --    ---------------------------------------------------------
  --    *********************************************************
  --    ***** to replace pattern ********************************
  --    **************[F]########################################
  --    #########################################################
  --    #########################################################
  --    #######################[S]*******************************
  --    **************************** region where we need *******
  --    ---------------------------------------------------------

  local firstline = range[1]
  local lastline = range[2]
  local startline = start[1]
  local startcolumn = start[2]
  local finishline = finish[1]
  local finishcolumn = finish[2]
  local lineno = startline
  local position = startcolumn
  local wrapped = startline < finishline

  while true do
    -- detect end of replacement process
    if wrapped and lineno > finishline then
      return
    end

    repeat
      local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
      position = string.find(line, pattern, position, true)
      if position ~= nil then
        -- detect end of replacement process
        if (wrapped and lineno == finishline and position > finishcolumn) then
          return
        end

        replace_in_line(pattern, replacement, lineno, position)
        position = position + #replacement
      end
    until position == nil

    -- wrap around the end of file
    if lineno ~= lastline then
      lineno = lineno + 1
    else
      lineno = firstline
      wrapped = true
    end
  end
end

-- highlight all occurrences of pattern on #lineno line
-- if {current} is passed then highlight current pattern individually
-- {current} is a list like this {start, finish}
-- return number of matches
-- lineno is one-based
local function highlight_in_line(pattern, lineno, current)
  current = current or {-1, -1}

  vim.api.nvim_buf_clear_namespace(0, M.highlighting_ns, lineno - 1, lineno)

  local matches = 0
  local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
  local start, finish = 0, 0
  repeat
    start, finish = string.find(line, pattern, start, true)
    if start ~= nil then
      if start == current[1] and finish == current[2] then
        vim.api.nvim_buf_set_extmark(0, M.highlighting_ns, lineno - 1, start - 1, {end_col = finish, hl_group = M.current_pattern_hl})
      else
        vim.api.nvim_buf_set_extmark(0, M.highlighting_ns, lineno - 1, start - 1, {end_col = finish, hl_group = M.regular_pattern_hl})
      end
      matches = matches + 1
      start = start + #pattern
    end
  until start == nil
  return matches
end

-- highlight all occurrences of pattern in range between firstline and lastline
-- return number of matches
-- lines are one-based
function M.highlight_in_range(pattern, firstline, lastline)
  vim.api.nvim_buf_clear_namespace(0, M.highlighting_ns, firstline, lastline)
  local matches = 0
  for lineno = firstline, lastline do
    matches = matches + highlight_in_line(pattern, lineno)
  end
  return matches
end

-- replace all occurrences of pattern to replacement
-- inside given range between firstline and lastline
-- starting from position {startline, startcolumn}
-- matches is number of all occurrences of pattern in the given range
-- lines and columns are one-based
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

        vim.api.nvim_win_set_cursor(0, {lineno, start - 1})
        if M.minimap_enabled then
          MiniMap.update_map_lines()
          MiniMap.update_map_scrollbar()
          MiniMap.update_map_integrations()
        end

        highlight_in_line(pattern, lineno, {start, finish})
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
          highlight_in_line(pattern, lineno)
          start = start + #pattern
        elseif input == 'a' then
          replace_in_range(pattern, replacement,
                          {firstline, lastline},
                          {lineno, start},
                          {startline, startcolumn - 1})
          vim.api.nvim_win_set_cursor(0, {startline, startcolumn})
          return matches
        elseif input == 'l' then
          replace_in_line(pattern, replacement, lineno, start)
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

function M.clear_highlighting()
  vim.api.nvim_buf_clear_namespace(0, M.highlighting_ns, 0, -1)
end

function M.setup(opts)
  M.minimap_enabled = opts.minimap_enabled
  M.regular_pattern_hl = opts.highlighting.regular_search_pattern
  M.current_pattern_hl = opts.highlighting.current_search_pattern
end

return M
