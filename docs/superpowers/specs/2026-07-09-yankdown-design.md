# yankdown.nvim Design

## Overview

`yankdown.nvim` is a Neovim Lua plugin that provides smart paste for Markdown buffers. When invoked, it checks the system clipboard for HTML content, converts that HTML to GitHub Flavored Markdown with `pandoc`, and inserts the Markdown at the cursor. If smart paste cannot run, it falls back to native Neovim paste behavior.

The v1 scope is intentionally small: macOS and Linux clipboard HTML support, `pandoc` as the only conversion engine, safe opt-in key interception, and mode-aware insertion.

## Goals

- Work only in `filetype=markdown` buffers.
- Provide explicit paste entry points by default.
- Optionally intercept Markdown buffer paste mappings when configured.
- Retrieve HTML clipboard content asynchronously.
- Convert HTML to Markdown through `pandoc`.
- Fall back to native paste when HTML, platform support, or dependencies are unavailable.
- Avoid surprising global mappings.

## Non-goals for v1

- Windows clipboard HTML support.
- A built-in HTML-to-Markdown converter.
- Exact emulation of every native paste edge case such as counts, dot-repeat, and register semantics.
- Adding new runtime dependencies beyond external user tools.

Windows should be left as a provider extension point because CF_HTML uses a custom `HTML Format` payload with byte-offset metadata and inconsistent PowerShell access.

## User-facing API

Default setup:

```lua
require("yankdown").setup({
  auto_intercept = false,
  notify = true,
})
```

Command:

```vim
:YankdownPaste
```

Lua API:

```lua
require("yankdown").paste({ direction = "after" })
require("yankdown").paste({ direction = "before" })
```

Plug mappings:

```vim
<Plug>(yankdown-paste-after)
<Plug>(yankdown-paste-before)
```

When `auto_intercept = true`, the plugin creates Markdown-buffer-local mappings for normal and visual paste keys such as `p` and `P`. The default remains explicit command or user mapping only.

## Architecture

### `lua/yankdown/init.lua`

Owns the public API:

- `setup(opts)` merges config, creates commands, defines plug mappings, and installs optional buffer-local interception.
- `paste(opts)` starts the smart paste flow.

### `lua/yankdown/clipboard.lua`

Detects the platform and retrieves HTML clipboard content asynchronously.

Providers for v1:

- macOS: `osascript` clipboard HTML retrieval.
- Linux Wayland: `wl-paste -t text/html`.
- Linux X11: `xclip -selection clipboard -t text/html`.

If no supported provider or executable exists, it returns a clean failure so paste can fall back.

### `lua/yankdown/convert.lua`

Checks for `pandoc` and converts HTML with:

```sh
pandoc -f html -t markdown_strict+gfm_markdown_blocks+pipe_tables --wrap=none
```

The module returns converted Markdown or a failure reason. It does not attempt built-in conversion.

### `lua/yankdown/paste.lua`

Handles mode-aware insertion and native fallback.

Supported v1 behavior:

- Normal mode: paste after or before cursor depending on direction.
- Visual mode: replace the selected range.
- Insert mode: insert at cursor.

The module strips carriage returns from converted output before insertion.

## Runtime flow

1. User invokes `:YankdownPaste`, a plug mapping, Lua API, or optional intercepted paste key.
2. Plugin checks the current buffer filetype.
   - If not Markdown, run native paste.
3. Plugin asks the selected clipboard provider for HTML.
   - If no provider, missing tool, or empty HTML, run native paste.
4. Plugin sends HTML to `pandoc`.
   - If `pandoc` is missing or conversion fails, warn once and run native paste.
5. Plugin normalizes the converted Markdown by stripping `\r`.
6. Plugin inserts Markdown according to current mode and direction.

All clipboard and conversion shell calls must be asynchronous so large clipboard payloads do not freeze Neovim.

## Error handling

- Non-Markdown buffer: silent native paste.
- No HTML clipboard payload: silent native paste.
- Missing clipboard utility: warn once per session, then native paste.
- Missing `pandoc`: warn once per session, then native paste.
- Pandoc conversion failure: warn once per session, then native paste.

Notifications are controlled by `notify = true`; fallback itself should never throw Lua errors during normal paste use.

## Testing approach

Use small Lua tests with mocked Neovim/system boundaries where possible.

Test areas:

- Provider selection for macOS, Wayland, X11, unsupported systems.
- Missing executable fallback decisions.
- Markdown-only activation.
- Pandoc command construction and failure handling.
- Normal, Visual, and Insert insertion behavior.
- Warn-once notification behavior.

CI should not require real `pandoc`, `wl-paste`, `xclip`, or `osascript`; integration with those tools can remain manual for v1.

## Recommended implementation order

1. Create plugin skeleton and config.
2. Add command, Lua API, and plug mappings.
3. Add native paste fallback.
4. Add async clipboard providers.
5. Add async pandoc conversion.
6. Add mode-aware insertion.
7. Add optional Markdown-buffer-local interception.
8. Add focused tests.

## Open extension points

- Windows clipboard provider.
- Custom converter command.
- Better native paste emulation if users need counts, repeat, or advanced register behavior.
