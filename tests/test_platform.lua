local t = require("tests.minitest")

--- Unmocked platform integration tests.
---
--- These tests run against the real environment (no mocking of vim.fn.has,
--- vim.fn.executable, vim.env, etc.). They validate that the actual platform
--- detection and clipboard provider paths work correctly on each OS.
---
--- On GitHub Actions CI:
---   - Windows runner → clipboard uses powershell (expected)
---   - macOS runner   → clipboard uses osascript
---   - Linux runner   → no display → clipboard is unsupported (expected)

t.test("real clipboard provider matches platform", function()
  t.reset("yankdown.clipboard")

  local is_win = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
  local is_mac = vim.fn.has("macunix") == 1
  local has_display = vim.env.DISPLAY ~= nil and vim.env.DISPLAY ~= vim.NIL
  local has_wayland = vim.env.WAYLAND_DISPLAY ~= nil and vim.env.WAYLAND_DISPLAY ~= vim.NIL

  local provider, err = require("yankdown.clipboard").provider()

  if is_win then
    -- Windows: clipboard uses PowerShell
    t.ok(provider ~= nil, "Windows should have a clipboard provider")
    if provider then
      t.eq(provider.name, "windows")
      t.ok(provider.command ~= nil, "provider should have a command")
      t.eq(provider.command[1], "powershell")
      t.eq(err, nil)
      print("PLATFORM: Windows — clipboard uses powershell")
    end
  elseif is_mac then
    -- macOS: osascript should be available
    t.ok(provider ~= nil, "macOS should have a clipboard provider")
    if provider then
      t.eq(provider.name, "macos")
      t.eq(err, nil)
      print("PLATFORM: macOS — clipboard uses osascript")
    end
  elseif has_display or has_wayland then
    -- Linux with display server: should have a provider or meaningful error
    t.ok(provider ~= nil or err ~= nil, "should have provider or error on Linux with display")
    if provider then
      print("PLATFORM: Linux — clipboard uses " .. provider.name)
    else
      print("PLATFORM: Linux — clipboard unavailable: " .. (err or "unknown"))
    end
  else
    -- Linux headless (CI) or no display
    t.eq(provider, nil, "clipboard provider should be nil without display")
    t.eq(err, "unsupported")
    print("PLATFORM: Linux headless — clipboard unsupported (expected)")
  end
end)

t.test("real check module probes without error", function()
  t.reset("yankdown.check")

  local deps = require("yankdown.check").check({ force = true })
  t.ok(#deps > 0, "check should return at least one dependency")

  local is_win = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
  if is_win then
    -- On Windows, clipboard uses PowerShell
    local ps_dep = vim.iter(deps):find(function(d)
      return d.name == "powershell"
    end)
    t.ok(ps_dep ~= nil, "Windows should have a powershell dep entry")
    -- PowerShell should be available on CI Windows runners
    t.eq(ps_dep.found, true)
    t.eq(ps_dep.platform, "Windows")
  end

  -- Format should never crash regardless of platform
  local formatted = require("yankdown.check").format(deps)
  t.ok(#formatted > 10, "format output should be non-trivial")
  t.ok(formatted:match("yankdown"), "format should mention yankdown")
end)

t.test("real native paste does not error", function()
  t.reset("yankdown.native")

  -- native.paste() feeds keys via nvim_feedkeys; in headless mode the keys
  -- are queued but never executed, so this should not throw.
  local native = require("yankdown.native")
  local ok1, err1 = pcall(native.paste, "after")
  local ok2, err2 = pcall(native.paste, "before")
  t.eq(ok1, true, "native paste after should not error: " .. tostring(err1))
  t.eq(ok2, true, "native paste before should not error: " .. tostring(err2))
  print("PLATFORM: native paste — OK")
end)
