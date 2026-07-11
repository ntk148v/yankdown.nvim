local t = require("tests.minitest")

t.test("setup keeps safe defaults", function()
  t.reset("yankdown")
  local yankdown = require("yankdown")
  yankdown.setup()
  t.eq(yankdown._config.auto_intercept, false)
  t.eq(yankdown._config.notify, true)
  t.eq(yankdown._config.check, "lazy")
end)

t.test("setup merges user options", function()
  t.reset("yankdown")
  local yankdown = require("yankdown")
  yankdown.setup({ auto_intercept = true, notify = false })
  t.eq(yankdown._config.auto_intercept, true)
  t.eq(yankdown._config.notify, false)
end)

t.test("setup lazy check does not notify or probe at startup", function()
  t.reset("yankdown")
  local notices = 0
  local probes = 0
  local old_notify = vim.notify
  vim.notify = function()
    notices = notices + 1
  end
  package.loaded["yankdown.check"] = {
    check = function()
      probes = probes + 1
      return {}
    end,
  }
  require("yankdown").setup()
  vim.notify = old_notify
  package.loaded["yankdown.check"] = nil
  t.eq(notices, 0)
  t.eq(probes, 0)
end)

t.test("setup startup check probes silently", function()
  t.reset("yankdown")
  local notices = 0
  local probes = 0
  local old_notify = vim.notify
  vim.notify = function()
    notices = notices + 1
  end
  package.loaded["yankdown.check"] = {
    check = function(opts)
      probes = probes + 1
      t.eq(opts.force, true)
      return {}
    end,
  }
  require("yankdown").setup({ check = "startup" })
  vim.notify = old_notify
  package.loaded["yankdown.check"] = nil
  t.eq(notices, 0)
  t.eq(probes, 1)
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
