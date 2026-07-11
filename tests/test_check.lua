local t = require("tests.minitest")

--- Helper to set up a controlled environment for a test.
--- Restores globals after the callback runs.
--- Properly handles vim.NIL — keys set to vim.NIL are removed from the
--- merged table so they read as nil (matching Neovim's real vim.env
--- semantics where setting a key to vim.NIL deletes the env var).
local function with_env(env, executable, fn)
  local old_has, old_executable, old_env = vim.fn.has, vim.fn.executable, vim.env
  vim.fn.has = function(name)
    return env.has[name] or 0
  end
  vim.fn.executable = function(name)
    return executable[name] and 1 or 0
  end
  -- Merge, then drop keys whose value is vim.NIL (emulates env-var deletion)
  local merged = vim.tbl_extend("force", vim.env, env.vars or {})
  for k, v in pairs(env.vars or {}) do
    if v == vim.NIL then
      merged[k] = nil
    end
  end
  vim.env = merged
  fn()
  vim.fn.has, vim.fn.executable, vim.env = old_has, old_executable, old_env
end

-- Shorthand: Unix + X11 + no Wayland
local X11 = { has = { unix = 1 }, vars = { DISPLAY = ":0", WAYLAND_DISPLAY = vim.NIL } }

-- Shorthand: Unix + Wayland + no X11
local WL = { has = { unix = 1 }, vars = { WAYLAND_DISPLAY = "wayland-1", DISPLAY = vim.NIL } }

-- ------------------------------------------------------------------
-- M.check()
-- ------------------------------------------------------------------

t.test("check finds pandoc when executable", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = true, xclip = true }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "pandoc"
    end)
    t.eq(d.found, true)
    t.eq(d.optional, false)
  end)
end)

t.test("check reports pandoc missing", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = false, xclip = true }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "pandoc"
    end)
    t.eq(d.found, false)
  end)
end)

t.test("check detects osascript on macOS", function()
  t.reset("yankdown.check")
  with_env({ has = { macunix = 1 } }, { osascript = true, pandoc = true }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "osascript"
    end)
    t.eq(d.found, true)
    t.eq(d.platform, "macOS")
  end)
end)

t.test("check detects missing osascript on macOS", function()
  t.reset("yankdown.check")
  with_env({ has = { macunix = 1 } }, { osascript = false, pandoc = true }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "osascript"
    end)
    t.eq(d.found, false)
  end)
end)

t.test("check detects xclip on X11", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = true, xclip = true }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "xclip"
    end)
    t.eq(d.found, true)
    t.eq(d.platform, "X11")
  end)
end)

t.test("check detects missing xclip on X11", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = true, xclip = false }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "xclip"
    end)
    t.eq(d.found, false)
  end)
end)

t.test("check detects wl-paste on Wayland", function()
  t.reset("yankdown.check")
  with_env(WL, { pandoc = true, ["wl-paste"] = true }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "wl-paste"
    end)
    t.eq(d.found, true)
    t.eq(d.platform, "Wayland")
  end)
end)

t.test("check detects missing wl-paste on Wayland", function()
  t.reset("yankdown.check")
  with_env(WL, { pandoc = true, ["wl-paste"] = false }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "wl-paste"
    end)
    t.eq(d.found, false)
  end)
end)

t.test("check reports Windows as unsupported", function()
  t.reset("yankdown.check")
  with_env({ has = { win32 = 1 } }, { pandoc = true }, function()
    local deps = require("yankdown.check").check()
    local d = vim.iter(deps):find(function(dep)
      return dep.name == "clipboard"
    end)
    t.eq(d.found, false)
    t.eq(d.optional, false)
    t.eq(d.platform, "Windows")
  end)
end)

t.test("check reports headless when no display", function()
  t.reset("yankdown.check")
  with_env(
    { has = { unix = 1 }, vars = { DISPLAY = vim.NIL, WAYLAND_DISPLAY = vim.NIL } },
    { pandoc = true },
    function()
      local deps = require("yankdown.check").check()
      local d = vim.iter(deps):find(function(dep)
        return dep.name == "display-server"
      end)
      t.eq(d.found, false)
      t.eq(d.optional, true)
      t.eq(d.platform, "headless")
    end
  )
end)

t.test("check skips xclip when only Wayland is active", function()
  t.reset("yankdown.check")
  with_env(WL, { pandoc = true, ["wl-paste"] = true }, function()
    local deps = require("yankdown.check").check()
    local xclip = vim.iter(deps):find(function(dep)
      return dep.name == "xclip"
    end)
    local wl = vim.iter(deps):find(function(dep)
      return dep.name == "wl-paste"
    end)
    t.eq(xclip, nil, "xclip not present on Wayland-only env")
    t.eq(wl.found, true)
  end)
end)

t.test("check skips wl-paste when only X11 is active", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = true, xclip = true }, function()
    local deps = require("yankdown.check").check()
    local wl = vim.iter(deps):find(function(dep)
      return dep.name == "wl-paste"
    end)
    local xclip = vim.iter(deps):find(function(dep)
      return dep.name == "xclip"
    end)
    t.eq(wl, nil, "wl-paste not present on X11-only env")
    t.eq(xclip.found, true)
  end)
end)

t.test("check treats xclip as fallback when both displays active and wl-paste missing", function()
  t.reset("yankdown.check")
  with_env(
    { has = { unix = 1 }, vars = { DISPLAY = ":0", WAYLAND_DISPLAY = "wayland-1" } },
    { pandoc = true, xclip = true, ["wl-paste"] = false },
    function()
      local deps = require("yankdown.check").check()
      local wl = vim.iter(deps):find(function(dep)
        return dep.name == "wl-paste"
      end)
      local xclip = vim.iter(deps):find(function(dep)
        return dep.name == "xclip"
      end)
      t.eq(wl.found, false)
      t.eq(wl.optional, true)
      t.eq(xclip.found, true)
      t.eq(require("yankdown.check").ok(deps), true)
    end
  )
end)

t.test("check caches by default and force refreshes", function()
  t.reset("yankdown.check")
  local calls = 0
  with_env(X11, { pandoc = true, xclip = true }, function()
    local old_executable = vim.fn.executable
    vim.fn.executable = function(name)
      calls = calls + 1
      return old_executable(name)
    end
    local check = require("yankdown.check")
    check.check()
    check.check()
    local cached_calls = calls
    check.check({ force = true })
    vim.fn.executable = old_executable
    t.eq(cached_calls, 2) -- pandoc + xclip once
    t.eq(calls, 4)
  end)
end)

-- ------------------------------------------------------------------
-- M.ok()
-- ------------------------------------------------------------------

t.test("ok returns true when all required deps found", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = true, xclip = true }, function()
    t.eq(require("yankdown.check").ok(), true)
  end)
end)

t.test("ok returns false when a required dep is missing", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = false, xclip = true }, function()
    t.eq(require("yankdown.check").ok(), false)
  end)
end)

t.test("ok returns false when Wayland tool missing", function()
  t.reset("yankdown.check")
  with_env(WL, { pandoc = true, ["wl-paste"] = false }, function()
    t.eq(require("yankdown.check").ok(), false)
  end)
end)

t.test("ok ignores optional deps", function()
  t.reset("yankdown.check")
  with_env(
    { has = { unix = 1 }, vars = { DISPLAY = vim.NIL, WAYLAND_DISPLAY = vim.NIL } },
    { pandoc = true },
    function()
      t.eq(require("yankdown.check").ok(), true)
    end
  )
end)

-- ------------------------------------------------------------------
-- M.warn_if_missing()
-- ------------------------------------------------------------------

t.test("warn_if_missing calls vim.notify when pandoc missing", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = false, xclip = true }, function()
    local notices = {}
    local old_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notices, { msg = msg, level = level })
    end
    require("yankdown.check").warn_if_missing({ notify = true })
    vim.notify = old_notify
    t.eq(#notices, 1)
    t.ok(notices[1].msg:match("pandoc"), "message mentions pandoc")
    t.eq(notices[1].level, vim.log.levels.WARN)
  end)
end)

t.test("warn_if_missing respects notify=false", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = false, xclip = true }, function()
    local notices = {}
    local old_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notices, { msg = msg, level = level })
    end
    require("yankdown.check").warn_if_missing({ notify = false })
    vim.notify = old_notify
    t.eq(#notices, 0)
  end)
end)

t.test("warn_if_missing stays silent when all deps met", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = true, xclip = true }, function()
    local notices = {}
    local old_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notices, { msg = msg, level = level })
    end
    require("yankdown.check").warn_if_missing({ notify = true })
    vim.notify = old_notify
    t.eq(#notices, 0)
  end)
end)

t.test("warn_if_missing lists all missing deps", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = false, xclip = false }, function()
    local notices = {}
    local old_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notices, { msg = msg, level = level })
    end
    require("yankdown.check").warn_if_missing({ notify = true })
    vim.notify = old_notify
    t.eq(#notices, 1)
    t.ok(notices[1].msg:match("pandoc"), "message mentions pandoc")
    t.ok(notices[1].msg:match("xclip"), "message mentions xclip")
  end)
end)

-- ------------------------------------------------------------------
-- M.format()
-- ------------------------------------------------------------------

t.test("format returns a multi-line string", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = true, xclip = true }, function()
    local str = require("yankdown.check").format()
    t.ok(#str > 20, "format output is non-trivial")
    t.ok(str:match("yankdown"), "contains module name")
    t.ok(str:match("pandoc"), "mentions pandoc")
    t.ok(str:match("xclip"), "mentions xclip")
    t.ok(str:match("✓"), "shows checkmark for found deps")
  end)
end)

t.test("format shows missing markers", function()
  t.reset("yankdown.check")
  with_env(X11, { pandoc = false, xclip = true }, function()
    local str = require("yankdown.check").format()
    t.ok(str:match("✗"), "shows cross for missing deps")
    t.ok(str:match("missing"), "notes that deps are missing")
  end)
end)

t.test("format includes optional tag", function()
  t.reset("yankdown.check")
  with_env(
    { has = { unix = 1 }, vars = { DISPLAY = vim.NIL, WAYLAND_DISPLAY = vim.NIL } },
    { pandoc = true },
    function()
      local str = require("yankdown.check").format()
      t.ok(str:match("optional"), "notes that display-server is optional")
    end
  )
end)
