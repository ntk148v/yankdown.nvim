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
