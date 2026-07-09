local M = {}

local function direction(opts)
  return opts.direction == "before" and "before" or "after"
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
