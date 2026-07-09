local t = require("tests.minitest")

local function with_env(env, executable, fn)
  local old_has, old_executable, old_env = vim.fn.has, vim.fn.executable, vim.env
  vim.fn.has = function(name) return env.has[name] or 0 end
  vim.fn.executable = function(name) return executable[name] and 1 or 0 end
  vim.env = vim.tbl_extend("force", vim.env, env.vars or {})
  fn()
  vim.fn.has, vim.fn.executable, vim.env = old_has, old_executable, old_env
end

t.test("selects macOS osascript provider", function()
  t.reset("yankdown.clipboard")
  with_env({ has = { macunix = 1 } }, { osascript = true }, function()
    local provider = require("yankdown.clipboard").provider()
    t.eq(provider.name, "macos")
    t.eq(provider.command[1], "osascript")
  end)
end)

t.test("selects Wayland wl-paste provider", function()
  t.reset("yankdown.clipboard")
  with_env({ has = { unix = 1 }, vars = { WAYLAND_DISPLAY = "wayland-1" } }, { ["wl-paste"] = true }, function()
    local provider = require("yankdown.clipboard").provider()
    t.eq(provider.name, "wayland")
    t.eq(provider.command[1], "wl-paste")
  end)
end)

t.test("selects X11 xclip provider", function()
  t.reset("yankdown.clipboard")
  with_env({ has = { unix = 1 }, vars = { DISPLAY = ":0", WAYLAND_DISPLAY = vim.NIL } }, { xclip = true }, function()
    local provider = require("yankdown.clipboard").provider()
    t.eq(provider.name, "x11")
    t.eq(provider.command[1], "xclip")
  end)
end)

t.test("unsupported Windows returns nil", function()
  t.reset("yankdown.clipboard")
  with_env({ has = { win32 = 1 } }, {}, function()
    local provider, err = require("yankdown.clipboard").provider()
    t.eq(provider, nil)
    t.eq(err, "unsupported")
  end)
end)
