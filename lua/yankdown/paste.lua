local M = {}

local function direction(opts)
  return opts.direction == "before" and "before" or "after"
end

local function lines(markdown)
  markdown = markdown:gsub("\r", "")
  return vim.split(markdown, "\n", { plain = true, trimempty = true })
end

function M.insert(markdown, dir)
  local mode = vim.api.nvim_get_mode().mode
  local out = lines(markdown)

  if mode:match("^[vV\22]") then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    vim.api.nvim_buf_set_text(0, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3], out)
    return
  end

  if mode:sub(1, 1) == "i" then
    vim.api.nvim_put(out, "c", true, true)
    return
  end

  vim.api.nvim_put(out, "l", dir ~= "before", true)
end

function M.start(opts, config)
  local dir = direction(opts or {})
  if vim.bo.filetype ~= "markdown" then
    require("yankdown.native").paste(dir)
    return
  end

  require("yankdown.native").paste(dir)
end

return M
