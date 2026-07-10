# Windows Clipboard HTML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Windows HTML clipboard support so yankdown.nvim can paste rich Windows clipboard content through the existing pandoc flow.

**Architecture:** Keep the existing provider model in `lua/yankdown/clipboard.lua`. Add one Windows provider that shells out to built-in PowerShell, extracts the HTML fragment when present, and lets existing `read_html()`, conversion, insertion, and fallback behavior stay unchanged.

**Tech Stack:** Lua 5.1, Neovim 0.10+ `vim.system`, Windows PowerShell/.NET `System.Windows.Forms`, existing minitest suite.

## Global Constraints

- Do not add dependencies; PowerShell and .NET clipboard APIs are built into supported Windows Neovim environments.
- Preserve existing macOS, Wayland, X11 behavior exactly.
- Preserve fallback behavior: no HTML or failed clipboard read falls back to native paste.
- Keep implementation in `lua/yankdown/clipboard.lua`; no new abstraction files.
- Run tests with `nvim --headless -c "luafile tests/run.lua" -c "q"`.

---

## File Structure

- Modify `lua/yankdown/clipboard.lua`
  - Add a small `windows_command()` helper returning a PowerShell command array.
  - Replace the current Windows `unsupported` branch with a provider that uses `powershell` or `pwsh`.
- Modify `tests/test_clipboard.lua`
  - Replace the unsupported Windows test with provider selection tests.
  - Add a read test proving Windows command output is passed through.
- Modify `README.md`
  - Update provider table and remove Windows from limitations.

---

### Task 1: Add Windows provider detection

**Files:**
- Modify: `lua/yankdown/clipboard.lua`
- Test: `tests/test_clipboard.lua`

**Interfaces:**
- Consumes: existing `M.provider()` returns `{ name: string, command: string[] }` or `nil, reason`.
- Produces: `M.provider()` returns `{ name = "windows", command = { "powershell"|"pwsh", ... } }` on Windows when a PowerShell executable exists.

- [ ] **Step 1: Replace the old Windows unsupported test with provider tests**

In `tests/test_clipboard.lua`, replace:

```lua
t.test("unsupported Windows returns nil", function()
  t.reset("yankdown.clipboard")
  with_env({ has = { win32 = 1 } }, {}, function()
    local provider, err = require("yankdown.clipboard").provider()
    t.eq(provider, nil)
    t.eq(err, "unsupported")
  end)
end)
```

with:

```lua
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -c "luafile tests/run.lua" -c "q"
```

Expected: FAIL because Windows still returns `unsupported`.

- [ ] **Step 3: Add minimal Windows command helper and provider**

In `lua/yankdown/clipboard.lua`, add this helper after `executable()`:

```lua
local function windows_command(shell)
  local script = table.concat({
    "Add-Type -AssemblyName System.Windows.Forms;",
    "if ([System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::Html)) {",
    "  $html = [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::Html);",
    "  $startMarker = '<!--StartFragment-->';",
    "  $endMarker = '<!--EndFragment-->';",
    "  $start = $html.IndexOf($startMarker);",
    "  $end = $html.IndexOf($endMarker);",
    "  if ($start -ge 0 -and $end -gt $start) {",
    "    $start = $start + $startMarker.Length;",
    "    $html.Substring($start, $end - $start);",
    "  } else {",
    "    $html;",
    "  }",
    "}",
  }, " ")

  return { shell, "-NoProfile", "-NonInteractive", "-Command", script }
end
```

Then replace the Windows branch in `M.provider()`:

```lua
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return nil, "unsupported"
  end
```

with:

```lua
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    if executable("powershell") then
      return { name = "windows", command = windows_command("powershell") }
    end
    if executable("pwsh") then
      return { name = "windows", command = windows_command("pwsh") }
    end
    return nil, "missing:powershell"
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -c "luafile tests/run.lua" -c "q"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/clipboard.lua tests/test_clipboard.lua
git commit -m "feat: add Windows clipboard provider"
```

---

### Task 2: Add read_html coverage for Windows output

**Files:**
- Modify: `tests/test_clipboard.lua`

**Interfaces:**
- Consumes: `M.read_html(callback)` runs `provider.command` through `vim.system`.
- Produces: Windows provider output is treated like other provider output: non-empty stdout becomes HTML; empty stdout becomes `no-html`.

- [ ] **Step 1: Add a Windows read_html test**

Append this test after `read_html returns stdout HTML` in `tests/test_clipboard.lua`:

```lua
t.test("read_html accepts Windows fragment stdout", function()
  t.reset("yankdown.clipboard")
  local old_system = vim.system
  local old_schedule = vim.schedule
  vim.schedule = function(fn)
    fn()
  end
  vim.system = function(cmd, opts, on_exit)
    t.eq(cmd[1], "powershell")
    on_exit({ code = 0, stdout = "<h1>Hello</h1>", stderr = "" })
    return {}
  end
  local clipboard = require("yankdown.clipboard")
  local old_provider = clipboard.provider
  clipboard.provider = function()
    return { name = "windows", command = { "powershell", "-NoProfile", "-NonInteractive", "-Command", "script" } }
  end
  local html, err
  clipboard.read_html(function(result, reason)
    html, err = result, reason
  end)
  clipboard.provider = old_provider
  vim.system = old_system
  vim.schedule = old_schedule
  t.eq(html, "<h1>Hello</h1>")
  t.eq(err, nil)
end)
```

- [ ] **Step 2: Run test to verify it passes**

Run:

```bash
nvim --headless -c "luafile tests/run.lua" -c "q"
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add tests/test_clipboard.lua
git commit -m "test: cover Windows clipboard HTML reads"
```

---

### Task 3: Update warnings and documentation

**Files:**
- Modify: `lua/yankdown/paste.lua`
- Modify: `README.md`
- Test: `tests/test_clipboard.lua`

**Interfaces:**
- Consumes: `clipboard.provider()` may return `missing:powershell`.
- Produces: user gets one warning for missing PowerShell; README documents Windows support.

- [ ] **Step 1: Add warning message for missing PowerShell**

In `lua/yankdown/paste.lua`, add this line to the `messages` table after the existing missing-tool messages:

```lua
  ["missing:powershell"] = "yankdown.nvim: PowerShell not found; falling back to native paste",
```

The resulting block should include:

```lua
local messages = {
  ["missing-pandoc"] = "yankdown.nvim: pandoc not found; falling back to native paste",
  ["pandoc-failed"] = "yankdown.nvim: pandoc conversion failed; falling back to native paste",
  ["missing:osascript"] = "yankdown.nvim: osascript not found; falling back to native paste",
  ["missing:wl-paste"] = "yankdown.nvim: wl-paste not found; falling back to native paste",
  ["missing:xclip"] = "yankdown.nvim: xclip not found; falling back to native paste",
  ["missing:powershell"] = "yankdown.nvim: PowerShell not found; falling back to native paste",
  ["clipboard-failed"] = "yankdown.nvim: HTML clipboard read failed; falling back to native paste",
  unsupported = "yankdown.nvim: HTML clipboard is unsupported on this platform; falling back to native paste",
}
```

- [ ] **Step 2: Update README provider table**

In `README.md`, replace:

```markdown
| Windows  | —           | Unsupported in v1           |
```

with:

```markdown
| Windows  | PowerShell  | Built-in Windows clipboard API |
```

- [ ] **Step 3: Update README limitations**

In `README.md`, remove this line:

```markdown
- Windows clipboard HTML is not supported.
```

Leave the other limitations in place.

- [ ] **Step 4: Run test suite**

Run:

```bash
nvim --headless -c "luafile tests/run.lua" -c "q"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/paste.lua README.md
git commit -m "docs: document Windows clipboard support"
```

---

## Final Verification

- [ ] **Run full tests**

```bash
nvim --headless -c "luafile tests/run.lua" -c "q"
```

Expected: PASS.

- [ ] **Manual Windows smoke test**

On Windows with pandoc installed:

```powershell
nvim -u NONE test.md
```

Inside Neovim:

```vim
:set rtp+=.
:set filetype=markdown
:lua require('yankdown').paste({ direction = 'after' })
```

Expected: copying rich text from a browser and running the paste command inserts Markdown converted from HTML. Copying plain text only falls back to native paste without an HTML warning.

- [ ] **Check docs mention Windows support**

```bash
grep -n "Windows" README.md
```

Expected: provider table lists `PowerShell`; limitations no longer say Windows is unsupported.

---

## Self-Review

- Spec coverage: Windows provider, no new dependencies, fallback behavior, docs, and tests are covered.
- Placeholder scan: no TBD/TODO/implement-later placeholders remain.
- Type consistency: provider shape remains `{ name, command }`; `read_html(callback)` contract is unchanged.
