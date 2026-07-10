Output yankdown-demo.gif

Set Shell bash
Set FontSize 18
Set Width 1400
Set Height 800
Set Theme { "name": "Flexoki-light", "black": "#100F0F", "red": "#AF3029", "green": "#66800B", "yellow": "#AD8301", "blue": "#205EA6", "magenta": "#A02F6F", "cyan": "#24837B", "white": "#B7B5AC", "brightBlack": "#575653", "brightRed": "#D14D41", "brightGreen": "#879A39", "brightYellow": "#D0A215", "brightBlue": "#4385BE", "brightMagenta": "#CE5D97", "brightCyan": "#3AA99F", "brightWhite": "#FFFCF0", "background": "#FFFCF0", "foreground": "#100F0F", "selection": "#E6E4D9", "cursor": "#100F0F" }
Set Padding 20
Set Framerate 30
Set PlaybackSpeed 1.5

# Setup
Hide
  Type "curl -sL https://pandoc.org/ > /tmp/pandoc_org.html"
  Enter
  Sleep 2s
  Type "export PATH=/tmp:$PATH"
  Enter
  Sleep 200ms
  Type "clear"
  Enter
Show

Type "echo 'yankdown.nvim: paste HTML as GitHub Flavored Markdown'"
Enter
Sleep 1s

Type "echo"
Enter
Type "echo '1. pandoc.org homepage copied to clipboard (links, code blocks, tables)'"
Enter
Sleep 1s

Type "echo"
Enter
Type "echo '2. Opening Neovim... paste via yankdown auto-conversion'"
Enter
Sleep 1s

Type "nvim /tmp/yankdown-demo.md"
Enter
Sleep 3s

# Set Flexoki-light colorscheme in Neovim
Type ":colorscheme flexoki-light"
Enter
Sleep 300ms

Type "i# Pandoc - a universal document converter"
Sleep 400ms
Escape
Sleep 300ms

# Paste (yankdown intercepts p in markdown buffers)
Type "p"
Sleep 5s

# Scroll through result
Escape
Sleep 200ms
Type "gg"
Sleep 800ms

ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms
ScrollDown 3
Sleep 800ms

Type "G"
Sleep 1s
ScrollUp 3
Sleep 1s

# Save to verify content
Type ":wq"
Enter
Sleep 1s

# Cat the saved file to prove conversion worked
Type "echo '=== CONVERTED MARKDOWN ==='"
Enter
Sleep 500ms
Type "head -60 /tmp/yankdown-demo.md"
Enter
Sleep 3s

Type "echo '=== Conversion successful! ==='"
Enter
Sleep 2s
