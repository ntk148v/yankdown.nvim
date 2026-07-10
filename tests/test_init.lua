local t = require("tests.minitest")

t.test("setup keeps safe defaults", function()
  t.reset("yankdown")
  local yankdown = require("yankdown")
  yankdown.setup()
  t.eq(yankdown._config.auto_intercept, false)
  t.eq(yankdown._config.notify, true)
end)

t.test("setup merges user options", function()
  t.reset("yankdown")
  local yankdown = require("yankdown")
  yankdown.setup({ auto_intercept = true, notify = false })
  t.eq(yankdown._config.auto_intercept, true)
  t.eq(yankdown._config.notify, false)
end)

t.test("paste delegates to paste module", function()
  t.reset("yankdown")
  package.loaded["yankdown.paste"] = {
    start = function(opts, config)
      _G.__yankdown_paste_call = { opts = opts, config = config }
    end,
  }
  local yankdown = require("yankdown")
  yankdown.setup({ notify = false })
  yankdown.paste({ direction = "before" })
  t.eq(_G.__yankdown_paste_call.opts.direction, "before")
  t.eq(_G.__yankdown_paste_call.config.notify, false)
  _G.__yankdown_paste_call = nil
  package.loaded["yankdown.paste"] = nil
end)

t.test("auto_intercept false does not create autocmd", function()
  t.reset("yankdown")
  local old_create_autocmd = vim.api.nvim_create_autocmd
  local created = false
  vim.api.nvim_create_autocmd = function()
    created = true
  end
  require("yankdown").setup({ auto_intercept = false })
  vim.api.nvim_create_autocmd = old_create_autocmd
  t.eq(created, false)
end)

t.test("auto_intercept true creates markdown filetype autocmd", function()
  t.reset("yankdown")
  local old_create_autocmd = vim.api.nvim_create_autocmd
  local autocmd
  vim.api.nvim_create_autocmd = function(event, opts)
    autocmd = { event = event, opts = opts }
  end
  require("yankdown").setup({ auto_intercept = true })
  vim.api.nvim_create_autocmd = old_create_autocmd
  t.eq(autocmd.event, "FileType")
  t.eq(autocmd.opts.pattern, "markdown")
end)
