local t = require("tests.minitest")

local function with_env(env, executable, fn)
  local old_has, old_executable, old_env = vim.fn.has, vim.fn.executable, vim.env
  vim.fn.has = function(name)
    return env.has[name] or 0
  end
  vim.fn.executable = function(name)
    return executable[name] and 1 or 0
  end
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

t.test("selects Windows PowerShell provider", function()
  t.reset("yankdown.clipboard")
  with_env({ has = { win32 = 1 } }, { powershell = true }, function()
    local provider = require("yankdown.clipboard").provider()
    t.eq(provider.name, "windows")
    t.eq(provider.command[1], "powershell")
    t.eq(provider.command[2], "-NoProfile")
  end)
end)

t.test("selects Windows pwsh provider when powershell is missing", function()
  t.reset("yankdown.clipboard")
  with_env({ has = { win64 = 1 } }, { pwsh = true }, function()
    local provider = require("yankdown.clipboard").provider()
    t.eq(provider.name, "windows")
    t.eq(provider.command[1], "pwsh")
    t.eq(provider.command[2], "-NoProfile")
  end)
end)

t.test("Windows without PowerShell reports missing:powershell", function()
  t.reset("yankdown.clipboard")
  with_env({ has = { win32 = 1 } }, {}, function()
    local provider, err = require("yankdown.clipboard").provider()
    t.eq(provider, nil)
    t.eq(err, "missing:powershell")
  end)
end)

t.test("read_html returns stdout HTML", function()
  t.reset("yankdown.clipboard")
  local old_system = vim.system
  local old_schedule = vim.schedule
  vim.schedule = function(fn)
    fn()
  end
  vim.system = function(cmd, opts, on_exit)
    t.eq(cmd[1], "wl-paste")
    on_exit({ code = 0, stdout = "<p>Hello</p>", stderr = "" })
    return {}
  end
  local clipboard = require("yankdown.clipboard")
  local old_provider = clipboard.provider
  clipboard.provider = function()
    return { name = "wayland", command = { "wl-paste", "-t", "text/html" } }
  end
  local html, err
  clipboard.read_html(function(result, reason)
    html, err = result, reason
  end)
  clipboard.provider = old_provider
  vim.system = old_system
  vim.schedule = old_schedule
  t.eq(html, "<p>Hello</p>")
  t.eq(err, nil)
end)

t.test("read_html treats empty stdout as no-html", function()
  t.reset("yankdown.clipboard")
  local old_system = vim.system
  local old_schedule = vim.schedule
  vim.schedule = function(fn)
    fn()
  end
  vim.system = function(cmd, opts, on_exit)
    on_exit({ code = 0, stdout = "", stderr = "" })
    return {}
  end
  local clipboard = require("yankdown.clipboard")
  local old_provider = clipboard.provider
  clipboard.provider = function()
    return { name = "x11", command = { "xclip", "-selection", "clipboard", "-t", "text/html", "-o" } }
  end
  local html, err
  clipboard.read_html(function(result, reason)
    html, err = result, reason
  end)
  clipboard.provider = old_provider
  vim.system = old_system
  vim.schedule = old_schedule
  t.eq(html, nil)
  t.eq(err, "no-html")
end)
