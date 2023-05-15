local M = {}

function M.minimap_integration()
  local cursorline = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, cursorline - 1, cursorline, false)[1]
  local position = string.find(line, M.pattern, 1, true)
  if position == nil then
    M.matches[cursorline] = nil
  end
  local matches = {}
  for _, tbl in pairs(M.matches) do
    table.insert(matches, tbl)
  end
  return matches
end

local function minimap_is_closed()
  local cur_win_id = MiniMap.current.win_data[vim.api.nvim_get_current_tabpage()]
  local minimap_is_open = cur_win_id ~= nil and vim.api.nvim_win_is_valid(cur_win_id)
  return not minimap_is_open
end

function M.before_replacement(pattern, firstline, lastline)
  M.pattern = pattern
  M.firstline = firstline
  M.lastline = lastline

  M.matches = {}
  for lineno = M.firstline, M.lastline do
    local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
    local position = string.find(line, M.pattern, 1, true)
    if position ~= nil then
      M.matches[lineno] = { line = lineno, hl_group = M.minimap_highlighting }
    end
  end

  -- add scalpelua integration to minimap and save previous integrations
  M.minimap_integrations = vim.deepcopy(MiniMap.config.integrations)
  table.insert(MiniMap.config.integrations, 1, M.minimap_integration)

  -- open if it wasn't opened already
  M.minimap_was_closed = minimap_is_closed()
  if M.minimap_was_closed then
    MiniMap.open()
  end

  M.matches = {}
  for lineno = firstline, lastline do
    local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
    local position = string.find(line, pattern, 1, true)
    if position ~= nil then
      M.matches[lineno] = { line = lineno, hl_group = M.minimap_highlighting }
    end
  end
end

function M.after_replacement()
  -- restore previous state of MiniMap integrations list
  MiniMap.config.integrations = M.minimap_integrations

  -- close if it wasn't opened initially
  if M.minimap_was_closed then
    MiniMap.close()
  end
end

function M.setup(opts)
  M.minimap_highlighting = opts.highlighting.minimap_integration
end

return M
