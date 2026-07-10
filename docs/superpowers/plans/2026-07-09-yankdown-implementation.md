# yankdown.nvim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small Neovim plugin that smart-pastes clipboard HTML as Markdown in Markdown buffers, with safe native-paste fallback.

**Architecture:** One public module owns setup and API, with focused helper modules for native fallback, clipboard HTML retrieval, Pandoc conversion, and mode-aware insertion. Tests use a tiny headless Neovim Lua harness with mocks, avoiding runtime dependencies and avoiding real clipboard/Pandoc tools in CI.

**Tech Stack:** Lua, Neovim 0.10+ (`vim.system`), external `pandoc`, macOS `osascript`, Wayland `wl-paste`, X11 `xclip`.

## Global Constraints

- Work only in `filetype=markdown` buffers.
- Default `auto_intercept = false`; no global paste-key hijacking by default.
- Provide `:YankdownPaste`, `<Plug>(yankdown-paste-after)`, `<Plug>(yankdown-paste-before)`, and `require("yankdown").paste({ direction = "after" | "before" })`.
- v1 supports macOS and Linux Wayland/X11 clipboard HTML providers.
- v1 does not support Windows clipboard HTML; expose it as an unsupported provider result.
- `pandoc` is the only conversion engine.
- No built-in HTML-to-Markdown converter.
- All clipboard and conversion shell calls must be asynchronous.
- Fallback to native paste for non-Markdown buffers, no HTML, missing tools, or conversion failure.
- Missing tools and Pandoc failures warn once per session when `notify = true`.
- No new runtime dependencies.

---

## File Structure

- Create `lua/yankdown/init.lua` — public API, config, user command, plug mappings, optional buffer-local key interception.
- Create `lua/yankdown/native.lua` — native paste fallback through fed keys.
- Create `lua/yankdown/clipboard.lua` — provider detection and async HTML clipboard retrieval.
- Create `lua/yankdown/convert.lua` — async Pandoc conversion.
- Create `lua/yankdown/paste.lua` — mode-aware insertion.
- Create `tests/minitest.lua` — tiny assert-based test runner and module reset helper.
- Create `tests/test_init.lua` — setup/API/config/keymap behavior.
- Create `tests/test_clipboard.lua` — provider selection and clipboard fallback behavior.
- Create `tests/test_convert.lua` — Pandoc conversion behavior.
- Create `tests/test_paste.lua` — insertion behavior.
- Create `tests/run.lua` — loads all tests and exits Neovim with pass/fail status.

---

### Task 1: Test Harness and Public API Skeleton

**Files:**

- Create: `tests/minitest.lua`
- Create: `tests/run.lua`
- Create: `tests/test_init.lua`
- Create: `lua/yankdown/init.lua`

**Interfaces:**

- Produces: `require("yankdown").setup(opts?: table): table`
- Produces: `require("yankdown").paste(opts?: table): nil`
- Produces: `require("yankdown")._config: table`
- Produces: `require("tests.minitest").test(name, fn)`, `eq(actual, expected)`, `ok(value, msg)`, `run()`

- [ ] **Step 1: Write the failing test harness**

Create `tests/minitest.lua`:

```lua
local M = { tests = {} }

function M.test(name, fn)
  table.insert(M.tests, { name = name, fn = fn })
end

function M.eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual), 2)
  end
end

function M.ok(value, msg)
  if not value then
    error(msg or "expected truthy value", 2)
  end
end

function M.reset(module)
  package.loaded[module] = nil
end

function M.run()
  local failed = 0
  for _, t in ipairs(M.tests) do
    local ok, err = pcall(t.fn)
    if ok then
      print("PASS " .. t.name)
    else
      failed = failed + 1
      print("FAIL " .. t.name .. "\n" .. err)
    end
  end
  if failed > 0 then
    vim.cmd("cquit")
  end
end

return M
```

Create `tests/run.lua`:

```lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/tests/?.lua;" .. package.path

require("test_init")
require("tests.minitest").run()
```

Create `tests/test_init.lua`:

```lua
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: FAIL because `module 'yankdown' not found`.

- [ ] **Step 3: Write minimal public API implementation**

Create `lua/yankdown/init.lua`:

```lua
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
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: all `test_init.lua` tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/init.lua tests/minitest.lua tests/run.lua tests/test_init.lua
git commit -m "feat: add yankdown public API skeleton"
```

---

### Task 2: Native Paste Fallback and Markdown Gate

**Files:**

- Create: `lua/yankdown/native.lua`
- Create: `lua/yankdown/paste.lua`
- Modify: `tests/run.lua`
- Create: `tests/test_paste.lua`

**Interfaces:**

- Consumes: `paste.start(opts: table, config: table): nil`
- Produces: `native.paste(direction: "after"|"before"): nil`
- Produces: `paste.start(opts, config)` falls back immediately when `vim.bo.filetype ~= "markdown"`

- [ ] **Step 1: Write failing fallback tests**

Modify `tests/run.lua` to load paste tests:

```lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/tests/?.lua;" .. package.path

require("test_init")
require("test_paste")
require("tests.minitest").run()
```

Create `tests/test_paste.lua`:

```lua
local t = require("tests.minitest")

t.test("native paste feeds p or P", function()
  t.reset("yankdown.native")
  local calls = {}
  local old_feedkeys, old_replace = vim.api.nvim_feedkeys, vim.api.nvim_replace_termcodes
  vim.api.nvim_replace_termcodes = function(keys) return keys end
  vim.api.nvim_feedkeys = function(keys, mode) table.insert(calls, { keys = keys, mode = mode }) end

  local native = require("yankdown.native")
  native.paste("after")
  native.paste("before")

  vim.api.nvim_feedkeys = old_feedkeys
  vim.api.nvim_replace_termcodes = old_replace
  t.eq(calls[1].keys, "p")
  t.eq(calls[2].keys, "P")
end)

t.test("non-markdown buffer uses native paste", function()
  t.reset("yankdown.paste")
  package.loaded["yankdown.native"] = {
    paste = function(direction) _G.__native_direction = direction end,
  }
  vim.bo.filetype = "lua"
  require("yankdown.paste").start({ direction = "before" }, { notify = false })
  t.eq(_G.__native_direction, "before")
  _G.__native_direction = nil
  package.loaded["yankdown.native"] = nil
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: FAIL because `yankdown.native` and `yankdown.paste` do not exist.

- [ ] **Step 3: Implement fallback modules**

Create `lua/yankdown/native.lua`:

```lua
local M = {}

function M.paste(direction)
  local key = direction == "before" and "P" or "p"
  local keys = vim.api.nvim_replace_termcodes(key, true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
end

return M
```

Create `lua/yankdown/paste.lua`:

```lua
local M = {}

local function direction(opts)
  return opts.direction == "before" and "before" or "after"
end

function M.start(opts, config)
  local dir = direction(opts or {})
  if vim.bo.filetype ~= "markdown" then
    require("yankdown.native").paste(dir)
    return
  end

  require("yankdown.native").paste(dir)
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/native.lua lua/yankdown/paste.lua tests/run.lua tests/test_paste.lua
git commit -m "feat: add native paste fallback"
```

---

### Task 3: Clipboard Provider Detection

**Files:**

- Create: `lua/yankdown/clipboard.lua`
- Modify: `tests/run.lua`
- Create: `tests/test_clipboard.lua`

**Interfaces:**

- Produces: `clipboard.provider(): table|nil`
- Produces provider shape `{ name: string, command: string[], missing?: string }`
- Produces: unsupported systems return `nil, "unsupported"`

- [ ] **Step 1: Write failing provider tests**

Modify `tests/run.lua`:

```lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/tests/?.lua;" .. package.path

require("test_init")
require("test_paste")
require("test_clipboard")
require("tests.minitest").run()
```

Create `tests/test_clipboard.lua`:

```lua
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: FAIL because `yankdown.clipboard` does not exist.

- [ ] **Step 3: Implement provider detection**

Create `lua/yankdown/clipboard.lua`:

```lua
local M = {}

local function executable(name)
  return vim.fn.executable(name) == 1
end

function M.provider()
  if vim.fn.has("macunix") == 1 then
    if executable("osascript") then
      return {
        name = "macos",
        command = {
          "osascript",
          "-e",
          'the clipboard as «class HTML»',
        },
      }
    end
    return nil, "missing:osascript"
  end

  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return nil, "unsupported"
  end

  if vim.env.WAYLAND_DISPLAY and executable("wl-paste") then
    return {
      name = "wayland",
      command = { "wl-paste", "-t", "text/html" },
    }
  end

  if vim.env.DISPLAY and executable("xclip") then
    return {
      name = "x11",
      command = { "xclip", "-selection", "clipboard", "-t", "text/html", "-o" },
    }
  end

  if vim.env.WAYLAND_DISPLAY then
    return nil, "missing:wl-paste"
  end

  if vim.env.DISPLAY then
    return nil, "missing:xclip"
  end

  return nil, "unsupported"
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/clipboard.lua tests/run.lua tests/test_clipboard.lua
git commit -m "feat: detect HTML clipboard providers"
```

---

### Task 4: Async Clipboard HTML Retrieval

**Files:**

- Modify: `lua/yankdown/clipboard.lua`
- Modify: `tests/test_clipboard.lua`

**Interfaces:**

- Consumes: `clipboard.provider()`
- Produces: `clipboard.read_html(callback: fun(html: string|nil, err: string|nil)): nil`

- [ ] **Step 1: Write failing async read tests**

Append to `tests/test_clipboard.lua`:

```lua
t.test("read_html returns stdout HTML", function()
  t.reset("yankdown.clipboard")
  local old_system = vim.system
  local old_provider
  vim.system = function(cmd, opts, on_exit)
    t.eq(cmd[1], "wl-paste")
    on_exit({ code = 0, stdout = "<p>Hello</p>", stderr = "" })
    return {}
  end
  local clipboard = require("yankdown.clipboard")
  old_provider = clipboard.provider
  clipboard.provider = function()
    return { name = "wayland", command = { "wl-paste", "-t", "text/html" } }
  end
  local html, err
  clipboard.read_html(function(result, reason)
    html, err = result, reason
  end)
  clipboard.provider = old_provider
  vim.system = old_system
  t.eq(html, "<p>Hello</p>")
  t.eq(err, nil)
end)

t.test("read_html treats empty stdout as no-html", function()
  t.reset("yankdown.clipboard")
  local old_system = vim.system
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
  t.eq(html, nil)
  t.eq(err, "no-html")
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: FAIL because `read_html` is nil.

- [ ] **Step 3: Implement async read_html**

Modify `lua/yankdown/clipboard.lua` by adding this before `return M`:

```lua
function M.read_html(callback)
  local provider, err = M.provider()
  if not provider then
    callback(nil, err)
    return
  end

  vim.system(provider.command, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, "clipboard-failed")
        return
      end

      local stdout = result.stdout or ""
      if stdout == "" then
        callback(nil, "no-html")
        return
      end

      callback(stdout, nil)
    end)
  end)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/clipboard.lua tests/test_clipboard.lua
git commit -m "feat: read clipboard HTML asynchronously"
```

---

### Task 5: Pandoc Conversion

**Files:**

- Create: `lua/yankdown/convert.lua`
- Modify: `tests/run.lua`
- Create: `tests/test_convert.lua`

**Interfaces:**

- Produces: `convert.html_to_markdown(html: string, callback: fun(markdown: string|nil, err: string|nil)): nil`
- Uses command: `pandoc -f html -t markdown_strict+gfm_markdown_blocks+pipe_tables --wrap=none`

- [ ] **Step 1: Write failing conversion tests**

Modify `tests/run.lua`:

```lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/tests/?.lua;" .. package.path

require("test_init")
require("test_paste")
require("test_clipboard")
require("test_convert")
require("tests.minitest").run()
```

Create `tests/test_convert.lua`:

```lua
local t = require("tests.minitest")

t.test("missing pandoc returns missing-pandoc", function()
  t.reset("yankdown.convert")
  local old_executable = vim.fn.executable
  vim.fn.executable = function(name) return name == "pandoc" and 0 or old_executable(name) end
  local markdown, err
  require("yankdown.convert").html_to_markdown("<p>Hello</p>", function(result, reason)
    markdown, err = result, reason
  end)
  vim.fn.executable = old_executable
  t.eq(markdown, nil)
  t.eq(err, "missing-pandoc")
end)

t.test("pandoc converts html and strips carriage returns", function()
  t.reset("yankdown.convert")
  local old_executable, old_system = vim.fn.executable, vim.system
  vim.fn.executable = function(name) return name == "pandoc" and 1 or old_executable(name) end
  vim.system = function(cmd, opts, on_exit)
    t.eq(cmd[1], "pandoc")
    t.eq(opts.stdin, "<p>Hello</p>")
    on_exit({ code = 0, stdout = "Hello\r\n", stderr = "" })
    return {}
  end
  local markdown, err
  require("yankdown.convert").html_to_markdown("<p>Hello</p>", function(result, reason)
    markdown, err = result, reason
  end)
  vim.fn.executable = old_executable
  vim.system = old_system
  t.eq(markdown, "Hello\n")
  t.eq(err, nil)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: FAIL because `yankdown.convert` does not exist.

- [ ] **Step 3: Implement Pandoc conversion**

Create `lua/yankdown/convert.lua`:

```lua
local M = {}

local pandoc_args = {
  "pandoc",
  "-f",
  "html",
  "-t",
  "markdown_strict+gfm_markdown_blocks+pipe_tables",
  "--wrap=none",
}

function M.html_to_markdown(html, callback)
  if vim.fn.executable("pandoc") ~= 1 then
    callback(nil, "missing-pandoc")
    return
  end

  vim.system(pandoc_args, { text = true, stdin = html }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, "pandoc-failed")
        return
      end

      callback((result.stdout or ""):gsub("\r", ""), nil)
    end)
  end)
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/convert.lua tests/run.lua tests/test_convert.lua
git commit -m "feat: convert clipboard HTML with pandoc"
```

---

### Task 6: Mode-Aware Markdown Insertion

**Files:**

- Modify: `lua/yankdown/paste.lua`
- Modify: `tests/test_paste.lua`

**Interfaces:**

- Produces: `paste.insert(markdown: string, direction: "after"|"before"): nil`
- Normal mode uses `vim.api.nvim_put(lines, "l", after, true)`.
- Visual mode replaces selected lines with `vim.api.nvim_buf_set_text`.
- Insert mode inserts at cursor with `vim.api.nvim_put(lines, "c", true, true)`.

- [ ] **Step 1: Write failing insertion tests**

Append to `tests/test_paste.lua`:

```lua
t.test("insert normal after uses linewise put after cursor", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function() return { mode = "n" } end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("# Hello\nWorld\n", "after")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.lines[1], "# Hello")
  t.eq(call.lines[2], "World")
  t.eq(call.type, "l")
  t.eq(call.after, true)
end)

t.test("insert normal before uses linewise put before cursor", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function() return { mode = "n" } end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("Hello", "before")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.after, false)
end)

t.test("insert insert-mode uses characterwise put", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function() return { mode = "i" } end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("Hello", "after")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.type, "c")
  t.eq(call.after, true)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: FAIL because `paste.insert` is nil.

- [ ] **Step 3: Implement mode-aware insertion**

Replace `lua/yankdown/paste.lua` with:

```lua
local M = {}

local function direction(opts)
  return opts.direction == "before" and "before" or "after"
end

local function lines(markdown)
  markdown = markdown:gsub("\r", "")
  return vim.split(markdown, "\n", { plain = true, trimempty = true })
end

function M.insert(markdown, dir)
  local mode = vim.api.nvim_get_mode().mode
  local out = lines(markdown)

  if mode:match("^[vV\22]") then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    vim.api.nvim_buf_set_text(0, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3], out)
    return
  end

  if mode:sub(1, 1) == "i" then
    vim.api.nvim_put(out, "c", true, true)
    return
  end

  vim.api.nvim_put(out, "l", dir ~= "before", true)
end

function M.start(opts, config)
  local dir = direction(opts or {})
  if vim.bo.filetype ~= "markdown" then
    require("yankdown.native").paste(dir)
    return
  end

  require("yankdown.native").paste(dir)
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/paste.lua tests/test_paste.lua
git commit -m "feat: insert converted markdown by mode"
```

---

### Task 7: Wire Smart Paste Pipeline and Warn Once

**Files:**

- Modify: `lua/yankdown/paste.lua`
- Modify: `tests/test_paste.lua`

**Interfaces:**

- Consumes: `clipboard.read_html(callback)`
- Consumes: `convert.html_to_markdown(html, callback)`
- Produces: warn-once behavior through local warning cache in `paste.lua`
- Produces: Markdown buffers use smart path, then fallback on each failure reason.

- [ ] **Step 1: Write failing pipeline tests**

Append to `tests/test_paste.lua`:

```lua
t.test("markdown buffer inserts converted html", function()
  t.reset("yankdown.paste")
  vim.bo.filetype = "markdown"
  package.loaded["yankdown.clipboard"] = {
    read_html = function(cb) cb("<p>Hello</p>", nil) end,
  }
  package.loaded["yankdown.convert"] = {
    html_to_markdown = function(html, cb)
      t.eq(html, "<p>Hello</p>")
      cb("Hello", nil)
    end,
  }
  package.loaded["yankdown.native"] = {
    paste = function() error("native paste should not run") end,
  }
  local paste = require("yankdown.paste")
  local old_insert = paste.insert
  local inserted
  paste.insert = function(markdown, direction) inserted = { markdown = markdown, direction = direction } end
  paste.start({ direction = "after" }, { notify = false })
  paste.insert = old_insert
  package.loaded["yankdown.clipboard"] = nil
  package.loaded["yankdown.convert"] = nil
  package.loaded["yankdown.native"] = nil
  t.eq(inserted.markdown, "Hello")
  t.eq(inserted.direction, "after")
end)

t.test("no html falls back silently", function()
  t.reset("yankdown.paste")
  vim.bo.filetype = "markdown"
  package.loaded["yankdown.clipboard"] = {
    read_html = function(cb) cb(nil, "no-html") end,
  }
  package.loaded["yankdown.native"] = {
    paste = function(direction) _G.__fallback_direction = direction end,
  }
  require("yankdown.paste").start({ direction = "before" }, { notify = true })
  package.loaded["yankdown.clipboard"] = nil
  package.loaded["yankdown.native"] = nil
  t.eq(_G.__fallback_direction, "before")
  _G.__fallback_direction = nil
end)

t.test("missing pandoc warns once", function()
  t.reset("yankdown.paste")
  vim.bo.filetype = "markdown"
  local notices = 0
  local old_notify = vim.notify
  vim.notify = function(msg, level)
    notices = notices + 1
    t.ok(msg:match("pandoc"))
  end
  package.loaded["yankdown.clipboard"] = {
    read_html = function(cb) cb("<p>Hello</p>", nil) end,
  }
  package.loaded["yankdown.convert"] = {
    html_to_markdown = function(html, cb) cb(nil, "missing-pandoc") end,
  }
  package.loaded["yankdown.native"] = {
    paste = function() end,
  }
  local paste = require("yankdown.paste")
  paste.start({ direction = "after" }, { notify = true })
  paste.start({ direction = "after" }, { notify = true })
  vim.notify = old_notify
  package.loaded["yankdown.clipboard"] = nil
  package.loaded["yankdown.convert"] = nil
  package.loaded["yankdown.native"] = nil
  t.eq(notices, 1)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: FAIL because `paste.start` still always falls back in Markdown buffers.

- [ ] **Step 3: Implement smart paste pipeline**

Replace `lua/yankdown/paste.lua` with:

```lua
local M = {}
local warned = {}

local function direction(opts)
  return opts.direction == "before" and "before" or "after"
end

local function fallback(dir)
  require("yankdown.native").paste(dir)
end

local function warn_once(reason, config)
  if not config.notify or warned[reason] then
    return
  end
  warned[reason] = true

  local messages = {
    ["missing-pandoc"] = "yankdown.nvim: pandoc not found; falling back to native paste",
    ["pandoc-failed"] = "yankdown.nvim: pandoc conversion failed; falling back to native paste",
    ["missing:osascript"] = "yankdown.nvim: osascript not found; falling back to native paste",
    ["missing:wl-paste"] = "yankdown.nvim: wl-paste not found; falling back to native paste",
    ["missing:xclip"] = "yankdown.nvim: xclip not found; falling back to native paste",
    ["clipboard-failed"] = "yankdown.nvim: HTML clipboard read failed; falling back to native paste",
    unsupported = "yankdown.nvim: HTML clipboard is unsupported on this platform; falling back to native paste",
  }

  local msg = messages[reason]
  if msg then
    vim.notify(msg, vim.log.levels.WARN)
  end
end

local function lines(markdown)
  markdown = markdown:gsub("\r", "")
  return vim.split(markdown, "\n", { plain = true, trimempty = true })
end

function M.insert(markdown, dir)
  local mode = vim.api.nvim_get_mode().mode
  local out = lines(markdown)

  if mode:match("^[vV\22]") then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    vim.api.nvim_buf_set_text(0, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3], out)
    return
  end

  if mode:sub(1, 1) == "i" then
    vim.api.nvim_put(out, "c", true, true)
    return
  end

  vim.api.nvim_put(out, "l", dir ~= "before", true)
end

function M.start(opts, config)
  local dir = direction(opts or {})
  config = config or { notify = true }

  if vim.bo.filetype ~= "markdown" then
    fallback(dir)
    return
  end

  require("yankdown.clipboard").read_html(function(html, clipboard_err)
    if not html then
      if clipboard_err ~= "no-html" then
        warn_once(clipboard_err, config)
      end
      fallback(dir)
      return
    end

    require("yankdown.convert").html_to_markdown(html, function(markdown, convert_err)
      if not markdown then
        warn_once(convert_err, config)
        fallback(dir)
        return
      end

      M.insert(markdown, dir)
    end)
  end)
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/paste.lua tests/test_paste.lua
git commit -m "feat: wire smart paste pipeline"
```

---

### Task 8: Optional Markdown Buffer Key Interception

**Files:**

- Modify: `lua/yankdown/init.lua`
- Modify: `tests/test_init.lua`

**Interfaces:**

- Consumes: `setup({ auto_intercept = boolean })`
- Produces: Markdown-only buffer-local mappings when `auto_intercept = true`
- Does not map paste keys when `auto_intercept = false`

- [ ] **Step 1: Write failing interception tests**

Append to `tests/test_init.lua`:

```lua
t.test("auto_intercept false does not create autocmd", function()
  t.reset("yankdown")
  local old_create_autocmd = vim.api.nvim_create_autocmd
  local created = false
  vim.api.nvim_create_autocmd = function() created = true end
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: FAIL because `setup({ auto_intercept = true })` does not create interception autocmd.

- [ ] **Step 3: Implement optional Markdown interception**

Replace `lua/yankdown/init.lua` with:

```lua
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
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/yankdown/init.lua tests/test_init.lua
git commit -m "feat: add optional markdown paste interception"
```

---

### Task 9: README and Final Verification

**Files:**

- Create: `README.md`
- Modify: `.gitignore` if it prevents committing project docs that should be tracked

**Interfaces:**

- Documents install, setup, dependencies, usage, config, v1 platform support, and limitations.
- Produces final runnable verification command.

- [ ] **Step 1: Write README content**

Create `README.md`:

````markdown
# yankdown.nvim

Smart paste for Markdown in Neovim.

When invoked in a Markdown buffer, `yankdown.nvim` reads HTML from the system clipboard, converts it to GitHub Flavored Markdown with `pandoc`, and inserts the result. If HTML is unavailable or a required tool is missing, it falls back to native paste.

## Requirements

- Neovim 0.10+
- `pandoc`
- One clipboard HTML provider:
  - macOS: `osascript`
  - Wayland: `wl-paste`
  - X11: `xclip`

Windows clipboard HTML is not supported in v1.

## Setup

```lua
require("yankdown").setup({
  auto_intercept = false,
  notify = true,
})
```
````

## Usage

Command:

```vim
:YankdownPaste
:YankdownPaste!
```

Lua:

```lua
require("yankdown").paste({ direction = "after" })
require("yankdown").paste({ direction = "before" })
```

Mappings:

```lua
vim.keymap.set({ "n", "x", "i" }, "<leader>p", function()
  require("yankdown").paste({ direction = "after" })
end)
```

Plug mappings are also available:

```vim
<Plug>(yankdown-paste-after)
<Plug>(yankdown-paste-before)
```

## Optional paste interception

```lua
require("yankdown").setup({
  auto_intercept = true,
})
```

This creates Markdown-buffer-local mappings for `p` and `P`. It does not create global mappings.

## Fallback behavior

Native paste is used when:

- the current buffer is not Markdown
- the clipboard has no HTML payload
- the platform/provider is unsupported
- the clipboard tool is missing
- `pandoc` is missing or conversion fails

````

- [ ] **Step 2: Ensure `.gitignore` does not hide implementation docs unintentionally**

Read `.gitignore`. If it contains `docs/superpowers`, leave it because superpowers specs/plans are process artifacts. Do not ignore `README.md`, `lua/`, or `tests/`.

- [ ] **Step 3: Run full test suite**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
````

Expected: every test prints `PASS`, and Neovim exits with status 0.

- [ ] **Step 4: Check git status**

Run:

```bash
git status --short
```

Expected: only intended implementation files are modified or untracked.

- [ ] **Step 5: Commit README and any final fixes**

```bash
git add README.md .gitignore lua/yankdown tests
git commit -m "docs: document yankdown usage"
```

---

## Maintenance Addendum: Performance, Cleanup, Tooling, and CI

**Goal:** benchmark the hot in-process paths, keep only low-risk source simplifications, add formatter/linter checks, add one regression test, and run everything in CI.

**Architecture:** the plugin is already thin; real paste latency is dominated by external clipboard tools and `pandoc`. Benchmark only the in-process Lua paths (`paste.insert` and `clipboard.provider`) so source cleanup can be checked for regressions without shelling out to platform tools.

**Global Constraints:**

- Do not add runtime dependencies.
- CI-only tools are allowed: `stylua`, `luacheck`, and Neovim.
- Benchmark output is informational; do not make CI fail on timing noise.
- Keep optimizations only when tests pass and the after-benchmark is not slower by more than 10% locally.

---

### Task 10: Add Benchmark Script and Capture Baseline

**Files:**

- Create: `scripts/benchmark.lua`

**Interfaces:**

- Consumes: `require("yankdown.paste").insert(markdown, direction)` and `require("yankdown.clipboard").provider()`.
- Produces: a runnable benchmark command: `nvim --headless -u NONE -l scripts/benchmark.lua`.

- [ ] **Step 1: Create benchmark script**

Create `scripts/benchmark.lua`:

```lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local paste = require("yankdown.paste")
local clipboard = require("yankdown.clipboard")

local function bench(name, iterations, fn)
  collectgarbage("collect")
  local started = vim.loop.hrtime()
  for _ = 1, iterations do
    fn()
  end
  local elapsed_ms = (vim.loop.hrtime() - started) / 1000000
  print(("%s\t%.6f"):format(name, elapsed_ms / iterations))
end

print("benchmark\tms_per_op")

local markdown = table.concat({
  "# Heading",
  "",
  "- one",
  "- two",
  "- three",
  "",
  "A short paragraph with **bold** text.",
}, "\n")

local old_mode = vim.api.nvim_get_mode
local old_put = vim.api.nvim_put
vim.api.nvim_get_mode = function()
  return { mode = "n" }
end
vim.api.nvim_put = function() end

bench("paste_insert_normal", 10000, function()
  paste.insert(markdown, "after")
end)

vim.api.nvim_get_mode = old_mode
vim.api.nvim_put = old_put

local old_has = vim.fn.has
local old_executable = vim.fn.executable
local old_wayland = vim.env.WAYLAND_DISPLAY
local old_display = vim.env.DISPLAY

vim.fn.has = function()
  return 0
end
vim.fn.executable = function(name)
  return name == "wl-paste" and 1 or 0
end
vim.env.WAYLAND_DISPLAY = "wayland-0"
vim.env.DISPLAY = nil

bench("clipboard_provider_wayland", 10000, function()
  local provider, err = clipboard.provider()
  if err or not provider or provider.name ~= "wayland" then
    error("expected wayland provider")
  end
end)

vim.fn.has = old_has
vim.fn.executable = old_executable
vim.env.WAYLAND_DISPLAY = old_wayland
vim.env.DISPLAY = old_display
```

- [ ] **Step 2: Run baseline benchmark**

Run:

```bash
nvim --headless -u NONE -l scripts/benchmark.lua | tee /tmp/yankdown-bench-before.tsv
```

Expected: output has this header and two numeric rows:

```text
benchmark	ms_per_op
paste_insert_normal	<number>
clipboard_provider_wayland	<number>
```

- [ ] **Step 3: Commit benchmark script**

```bash
git add scripts/benchmark.lua
git commit -m "test: add benchmark script"
```

---

### Task 11: Remove Redundant Paste Helpers Without Changing Behavior

**Files:**

- Modify: `lua/yankdown/paste.lua`
- Test: `tests/test_paste.lua`

**Interfaces:**

- Consumes: existing `paste.start(opts, config)` and `paste.insert(markdown, direction)` public module functions.
- Produces: same function signatures; warning messages table is hoisted once per module load, and the one-line `fallback()` wrapper is removed.

- [ ] **Step 1: Add regression test for warning suppression**

Append this test to `tests/test_paste.lua`, before the end of the file:

```lua
t.test("notify false suppresses fallback warnings", function()
  t.reset("yankdown.paste")
  vim.bo.filetype = "markdown"
  local notices = 0
  local old_notify = vim.notify
  vim.notify = function()
    notices = notices + 1
  end
  package.loaded["yankdown.clipboard"] = {
    read_html = function(cb)
      cb("<p>Hello</p>", nil)
    end,
  }
  package.loaded["yankdown.convert"] = {
    html_to_markdown = function(_, cb)
      cb(nil, "missing-pandoc")
    end,
  }
  package.loaded["yankdown.native"] = {
    paste = function() end,
  }

  require("yankdown.paste").start({ direction = "after" }, { notify = false })

  vim.notify = old_notify
  package.loaded["yankdown.clipboard"] = nil
  package.loaded["yankdown.convert"] = nil
  package.loaded["yankdown.native"] = nil
  t.eq(notices, 0)
end)
```

- [ ] **Step 2: Run test to verify current behavior**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: every test prints `PASS`, including `PASS notify false suppresses fallback warnings`.

- [ ] **Step 3: Replace `lua/yankdown/paste.lua` with cleaned implementation**

```lua
local M = {}
local warned = {}

local messages = {
  ["missing-pandoc"] = "yankdown.nvim: pandoc not found; falling back to native paste",
  ["pandoc-failed"] = "yankdown.nvim: pandoc conversion failed; falling back to native paste",
  ["missing:osascript"] = "yankdown.nvim: osascript not found; falling back to native paste",
  ["missing:wl-paste"] = "yankdown.nvim: wl-paste not found; falling back to native paste",
  ["missing:xclip"] = "yankdown.nvim: xclip not found; falling back to native paste",
  ["clipboard-failed"] = "yankdown.nvim: HTML clipboard read failed; falling back to native paste",
  unsupported = "yankdown.nvim: HTML clipboard is unsupported on this platform; falling back to native paste",
}

local function direction(opts)
  return opts.direction == "before" and "before" or "after"
end

local function warn_once(reason, config)
  if not config.notify or warned[reason] then
    return
  end
  warned[reason] = true

  local msg = messages[reason]
  if msg then
    vim.notify(msg, vim.log.levels.WARN)
  end
end

local function lines(markdown)
  markdown = markdown:gsub("\r", "")
  return vim.split(markdown, "\n", { plain = true, trimempty = true })
end

function M.insert(markdown, dir)
  local mode = vim.api.nvim_get_mode().mode
  local out = lines(markdown)

  if mode:match("^[vV\22]") then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    vim.api.nvim_buf_set_text(0, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3], out)
    return
  end

  if mode:sub(1, 1) == "i" then
    vim.api.nvim_put(out, "c", true, true)
    return
  end

  vim.api.nvim_put(out, "l", dir ~= "before", true)
end

function M.start(opts, config)
  local dir = direction(opts or {})
  config = config or { notify = true }

  if vim.bo.filetype ~= "markdown" then
    require("yankdown.native").paste(dir)
    return
  end

  require("yankdown.clipboard").read_html(function(html, clipboard_err)
    if not html then
      if clipboard_err ~= "no-html" then
        warn_once(clipboard_err, config)
      end
      require("yankdown.native").paste(dir)
      return
    end

    require("yankdown.convert").html_to_markdown(html, function(markdown, convert_err)
      if not markdown then
        warn_once(convert_err, config)
        require("yankdown.native").paste(dir)
        return
      end

      M.insert(markdown, dir)
    end)
  end)
end

return M
```

- [ ] **Step 4: Run tests after cleanup**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: every test prints `PASS` and Neovim exits with status 0.

- [ ] **Step 5: Run after benchmark and compare**

Run:

```bash
nvim --headless -u NONE -l scripts/benchmark.lua | tee /tmp/yankdown-bench-after.tsv
awk 'NR==FNR && NR>1 { before[$1]=$2; next } NR>1 { printf "%s before=%s after=%s change=%+.1f%%\n", $1, before[$1], $2, (($2 - before[$1]) / before[$1]) * 100 }' /tmp/yankdown-bench-before.tsv /tmp/yankdown-bench-after.tsv
```

Expected: both benchmark names print. Keep the cleanup if each local change is less than `+10.0%`; revert `lua/yankdown/paste.lua` if either row is slower by `+10.0%` or more.

- [ ] **Step 6: Commit cleanup and regression test**

```bash
git add lua/yankdown/paste.lua tests/test_paste.lua
git commit -m "refactor: simplify paste fallback handling"
```

---

### Task 12: Add Format and Lint Configuration

**Files:**

- Create: `.stylua.toml`
- Create: `.luacheckrc`

**Interfaces:**

- Produces: `stylua --check lua tests scripts` and `luacheck lua tests scripts` as local/CI commands.

- [ ] **Step 1: Add StyLua config**

Create `.stylua.toml`:

```toml
column_width = 120
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

- [ ] **Step 2: Add luacheck config**

Create `.luacheckrc`:

```lua
std = "lua51"
globals = { "vim" }
unused_args = false
max_line_length = false
```

- [ ] **Step 3: Run formatter**

Run:

```bash
stylua lua tests scripts
```

Expected: command exits with status 0. If `stylua` is missing, install it locally with the package manager you already use; do not commit installer output or generated caches.

- [ ] **Step 4: Run format check**

Run:

```bash
stylua --check lua tests scripts
```

Expected: command exits with status 0.

- [ ] **Step 5: Run lint**

Run:

```bash
luacheck lua tests scripts
```

Expected: command exits with status 0 and reports no warnings.

- [ ] **Step 6: Run tests**

Run:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Expected: every test prints `PASS` and Neovim exits with status 0.

- [ ] **Step 7: Commit tooling config**

```bash
git add .stylua.toml .luacheckrc lua tests scripts
git commit -m "chore: add lua format and lint checks"
```

---

### Task 13: Add CI Job for Format, Lint, Tests, and Benchmark Smoke

**Files:**

- Create: `.github/workflows/ci.yml`

**Interfaces:**

- Consumes: `.stylua.toml`, `.luacheckrc`, `tests/run.lua`, and `scripts/benchmark.lua`.
- Produces: GitHub Actions workflow named `CI`.

- [ ] **Step 1: Create CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Neovim and Lua tooling
        run: |
          sudo apt-get update
          sudo apt-get install -y lua5.1 luarocks neovim
          sudo luarocks install luacheck

      - name: Install StyLua
        uses: JohnnyMorganz/stylua-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          version: latest
          args: --version

      - name: Format check
        run: stylua --check lua tests scripts

      - name: Lint
        run: luacheck lua tests scripts

      - name: Tests
        run: nvim --headless -u NONE -l tests/run.lua

      - name: Benchmark smoke
        run: nvim --headless -u NONE -l scripts/benchmark.lua
```

- [ ] **Step 2: Run CI commands locally in the same order**

Run:

```bash
stylua --check lua tests scripts
luacheck lua tests scripts
nvim --headless -u NONE -l tests/run.lua
nvim --headless -u NONE -l scripts/benchmark.lua
```

Expected: all four commands exit with status 0. The benchmark prints timing rows; do not compare timing in CI.

- [ ] **Step 3: Commit CI workflow**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add format lint test workflow"
```

---

## Self-Review Notes

- Spec coverage: public API, safe defaults, macOS/Linux providers, unsupported Windows, Pandoc-only conversion, async shell calls, fallback behavior, mode-aware insertion, warn-once notifications, focused tests, benchmark script, source cleanup, formatter/linter config, and CI are all covered by tasks.
- Placeholder scan: no placeholder task steps remain; each code-changing step includes concrete file content or concrete patch content.
- Type consistency: `setup`, `paste`, `clipboard.provider`, `clipboard.read_html`, `convert.html_to_markdown`, `paste.start`, `paste.insert`, and `native.paste` signatures are consistent across tasks. The maintenance addendum preserves existing public signatures.
- Scope check: this is one coherent plugin v1 plus a maintenance/tooling addendum; Windows and custom converters remain documented extension points, not implementation tasks.
