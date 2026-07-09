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

local function intercept_buffer(buf)
  local opts = { buffer = buf, silent = true }
  vim.keymap.set({ "n", "x" }, "p", function()
    require("yankdown").paste({ direction = "after" })
  end, opts)
  vim.keymap.set({ "n", "x" }, "P", function()
    require("yankdown").paste({ direction = "before" })
  end, opts)
end

local function maybe_intercept()
  if not M._config.auto_intercept then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    group = vim.api.nvim_create_augroup("yankdown_intercept", { clear = true }),
    callback = function(args)
      intercept_buffer(args.buf)
    end,
  })
end

function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  maybe_create_command()
  map_plug("<Plug>(yankdown-paste-after)", "after")
  map_plug("<Plug>(yankdown-paste-before)", "before")
  maybe_intercept()
  return M._config
end

function M.paste(opts)
  require("yankdown.paste").start(opts or {}, M._config)
end

return M
