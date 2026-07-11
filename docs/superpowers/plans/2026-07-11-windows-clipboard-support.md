# Windows clipboard HTML support implementation plan

## Status

`yankdown.nvim` does **not** currently support Windows HTML clipboard paste.

Current code explicitly treats Windows as unsupported:

- `lua/yankdown/clipboard.lua` returns `nil, "unsupported"` for `win32`/`win64`.
- `lua/yankdown/check.lua` reports a missing Windows `clipboard` dependency.
- `README.md` documents Windows as unsupported.

A naive PowerShell command that reads `[System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::Html)` is not enough by itself because Windows HTML clipboard data uses the CF_HTML format, which can include metadata headers such as `StartHTML`, `EndHTML`, `StartFragment`, and `EndFragment`. We need parse/normalize that payload before sending it to `pandoc`.

## Goals

- Detect Windows as a supported clipboard provider.
- Read HTML clipboard content asynchronously without blocking Neovim.
- Correctly parse CF_HTML and extract the intended HTML fragment.
- Preserve existing fallback behavior when no HTML is available, PowerShell is unavailable, or clipboard access fails.
- Keep CI tests fully mocked; do not require a real Windows clipboard in unit tests.

## Proposed design

### 1. Add CF_HTML parser

Create `lua/yankdown/cf_html.lua` with:

```lua
parse(payload: string): string|nil, string|nil
```

Behavior:

- If `payload` is empty, return `nil, "no-html"`.
- If CF_HTML headers include valid `StartFragment`/`EndFragment`, return that byte range.
- Else if headers include valid `StartHTML`/`EndHTML`, return that byte range.
- Else if payload looks like plain HTML, return payload unchanged.
- Else return `nil, "no-html"`.

Important: CF_HTML offsets are byte offsets. Lua string slicing is byte-based, so `string.sub` is appropriate.

### 2. Add Windows provider

Update `lua/yankdown/clipboard.lua`:

- On `win32` or `win64`, require `powershell.exe`.
- Provider command should run PowerShell with:
  - `-NoProfile`
  - `-NonInteractive`
  - `-STA` for clipboard access
  - `-Command` script using `System.Windows.Forms.Clipboard` and `TextDataFormat.Html`
- Return provider metadata, for example:

```lua
{
  name = "windows",
  command = { "powershell.exe", "-NoProfile", "-NonInteractive", "-STA", "-Command", script },
  parse = require("yankdown.cf_html").parse,
}
```

Then update `read_html()` so provider-specific parsers can normalize stdout before invoking the callback.

### 3. Update dependency checks

Update `lua/yankdown/check.lua`:

- On Windows, check `powershell.exe`.
- Mark it required.
- Reason: `Windows clipboard HTML read`.
- Platform: `Windows`.

### 4. Update warnings

Update `lua/yankdown/paste.lua` warning messages:

- Add `missing:powershell` message.
- Keep `unsupported` for unknown platforms.

### 5. Add tests

#### `tests/test_cf_html.lua`

Cover:

- Extracts `StartFragment`/`EndFragment` range.
- Falls back to `StartHTML`/`EndHTML` range when fragment offsets are missing.
- Accepts plain HTML payloads.
- Returns `no-html` for empty/non-HTML payloads.
- Handles invalid/missing offsets safely.

#### `tests/test_clipboard.lua`

Cover:

- Windows selects `powershell.exe` provider when executable exists.
- Command includes `-STA`.
- Command requests `TextDataFormat.Html`.
- Missing PowerShell returns `nil, "missing:powershell"`.
- `read_html()` applies provider parser to CF_HTML stdout before callback.

#### `tests/test_check.lua`

Cover:

- Windows dependency check finds `powershell.exe`.
- Missing PowerShell makes `check.ok()` false.
- Formatted output mentions Windows/PowerShell.

#### `tests/run.lua`

Require `test_cf_html`.

### 6. Documentation

Update `README.md`:

- Change Windows row from unsupported to `powershell.exe`.
- Add note that Windows support reads CF_HTML through PowerShell/.NET clipboard APIs.

Update design docs if they are still considered current.

## Validation

Run:

```sh
nvim --headless -u NONE -c "luafile tests/run.lua" -c "qa"
```

Manual Windows smoke test:

1. Copy rich HTML from a browser on Windows.
2. Open a Markdown buffer in Neovim.
3. Trigger yankdown paste.
4. Confirm converted Markdown is inserted.
5. Copy plain text only and confirm native paste fallback.

## Commit plan

Use separate commits:

1. `test: cover Windows CF_HTML clipboard support`
2. `feat: support Windows HTML clipboard provider`
3. `docs: document Windows clipboard support`
