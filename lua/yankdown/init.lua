local M = {}

local defaults = {
  auto_intercept = false,
  notify = true,
}

M._config = vim.deepcopy(defaults)

local function map_plug(lhs, direction)
  vim.keymap.set({ "n", "x", "i" }, lhs, function()
    require("yankdown").paste({ direction = direction })
  end, { silent = true })
end

local function maybe_create_command()
  pcall(vim.api.nvim_create_user_command, "YankdownPaste", function(args)
    local direction = args.bang and "before" or "after"
    require("yankdown").paste({ direction = direction })
  end, { bang = true })
end

function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  maybe_create_command()
  map_plug("<Plug>(yankdown-paste-after)", "after")
  map_plug("<Plug>(yankdown-paste-before)", "before")
  return M._config
end

function M.paste(opts)
  require("yankdown.paste").start(opts or {}, M._config)
end

return M
