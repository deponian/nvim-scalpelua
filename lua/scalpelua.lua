local M = {}

local utils = require("scalpelua.utils")
local minimap = require("scalpelua.minimap")
M.highlighting_ns = utils.highlighting_ns
M.dehighlighting_ns = utils.dehighlighting_ns

local DEFAULT_OPTS = {
  minimap_enabled = false,
  separator = "»",
  highlighting = {
    regular_search_pattern = "Search",
    current_search_pattern = "WildMenu",
    minimap_integration = "Constant",
  },
  dehighlighting = {
    enabled = false,
    group = "LineNr",
    range = 3
  },
  save_search_pattern = true
}

function M.setup(config)
  local opts = vim.tbl_deep_extend("force", DEFAULT_OPTS, config or {})
  M.config = opts

  require("scalpelua.utils").setup(opts)
  if opts.minimap_enabled then
    require("scalpelua.minimap").setup(opts)
  end

  vim.api.nvim_create_user_command(
    'Scalpelua',
    M.scalpelua,
    {
      range = true,
      nargs = 1,
    }
  )
  vim.keymap.set('v', '<Plug>(Scalpelua)', [[:Scalpelua "<C-R>=luaeval('require("scalpelua").get_oneline_selection()')<CR>" » ""<Left>]])
  vim.keymap.set('v', '<Plug>(ScalpeluaMultiline)', [[:Scalpelua "" » ""<Left><Left><Left><Left><Left><Left>]])
end

function M.scalpelua(parameters)
  -- what to replace and what to replace with
  local pattern, replacement
  -- start and end of range where replacement will be performed
  local firstline, lastline
  -- current cursor position if we're operating on whole buffer
  -- start of range if we're operating on the range
  local startline, startcolumn

  if parameters.line1 == parameters.line2 then
    -- operate on whole buffer if we replacing one word
    firstline = 1
    lastline = vim.api.nvim_buf_line_count(0)
    startline = vim.api.nvim_win_get_cursor(0)[1]
    startcolumn = vim.api.nvim_win_get_cursor(0)[2] + 1
  else
    -- operate on the range
    firstline = math.min(parameters.line1, parameters.line2)
    lastline = math.max(parameters.line1, parameters.line2)
    startline = firstline
    startcolumn = 1
  end

  pattern, replacement = string.match(parameters.args, '^"(.+)" ' .. M.config.separator .. ' "(.*)"$')

  -- activate MiniMap if it's enabled
  if M.config.minimap_enabled then
    minimap.before_replacement(pattern, firstline, lastline)
  end

  -- main part
  vim.o.cursorline = false
  local matches = utils.highlight_in_range(pattern, firstline, lastline)
  local replaced = utils.replace_all(pattern, replacement, firstline, lastline, startline, startcolumn, matches)
  vim.o.cursorline = true

  -- report
  print(string.format("%s substitution%s out of %s matches", replaced, (replaced == 1) and '' or 's', matches))

  -- clear our highlighting
  vim.api.nvim_buf_clear_namespace(0, M.highlighting_ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(0, M.dehighlighting_ns, 0, -1)

  -- save pattern in the search register
  if M.config.save_search_pattern then
    vim.fn.setreg('/', [[\V\C]] .. vim.fn.escape(pattern, [[\]]))
  end

  if M.config.minimap_enabled then
    minimap.after_replacement()
  end
end

-- thanks to https://github.com/kristijanhusak/neovim-config/blob/master/nvim/lua/partials/utils.lua
function M.get_oneline_selection()
  local start = vim.fn.getpos("'<")
  local finish = vim.fn.getpos("'>")
  local lines = math.abs(finish[2] - start[2]) + 1
  if lines == 1 then
    local line = vim.api.nvim_buf_get_lines(0, start[2] - 1, finish[2], false)[1]
    return string.sub(line, start[3], finish[3])
  else
    return 'multiline is not supported'
  end
end

return M
