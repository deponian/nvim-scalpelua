local M = {}

local function minimap_integration()
  local pattern = vim.fn.getreg("p")
  local firstline = vim.fn.getreg("f")
  local lastline = vim.fn.getreg("l")
  local matches = {}
  for lineno = firstline, lastline do
    local line = vim.api.nvim_buf_get_lines(0, lineno - 1, lineno, false)[1]
    local position = string.find(line, pattern, 1, true)
    if position ~= nil then
      table.insert(matches, { line = lineno, hl_group = M.minimap_highlighting })
    end
  end
  return matches
end

local function minimap_is_closed()
  local cur_win_id = MiniMap.current.win_data[vim.api.nvim_get_current_tabpage()]
  local minimap_is_open = cur_win_id ~= nil and vim.api.nvim_win_is_valid(cur_win_id)
  return not minimap_is_open
end

function M.before_replacement(pattern, firstline, lastline)
  -- save registers
  M.reg_p = vim.fn.getreg("p")
  M.reg_f = vim.fn.getreg("f")
  M.reg_l = vim.fn.getreg("l")

  -- make pattern, firstline and lastline accessable from minimap_integration()
  vim.fn.setreg("p", pattern)
  vim.fn.setreg("f", firstline)
  vim.fn.setreg("l", lastline)

  -- add scalpelua integration to minimap and save previous integrations
  M.minimap_integrations = vim.deepcopy(MiniMap.config.integrations)
  table.insert(MiniMap.config.integrations, 1, minimap_integration)

  -- open if it wasn't opened already
  M.minimap_was_closed = minimap_is_closed()
  if M.minimap_was_closed then
    MiniMap.open()
  end
end

function M.after_replacement()
  -- restore registers
  vim.fn.setreg("p", M.reg_p)
  vim.fn.setreg("f", M.reg_f)
  vim.fn.setreg("l", M.reg_l)

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
