# tmux-coffee

> Forked from [tmux-tea](https://github.com/2kabhishek/tmux-tea) by [2kabhishek](https://github.com/2kabhishek)

A tmux session manager with a beautiful UI and enhanced session management features.

## Features

- **Fuzzy Search**: fzf integration for intuitive session selection
- **Session Previews**: Visual previews of existing sessions and directory contents
- **Zoxide Integration**: Directory-based session creation with smart directory jumping
- **Create Sessions**: Beautiful popup dialog to create new sessions (`Ctrl+n`)
- **Delete Sessions**: Confirmation dialog before deleting sessions (`Ctrl+d`)
- **Default Mode**: Start in sessions mode by default

## Installation

Add to your `~/.tmux.conf`:

```bash
set -g @plugin 'haidinhtuan/tmux-coffee'
```

Then press `prefix + I` to install.

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl+s` | Session mode (existing sessions) |
| `Ctrl+f` | Directory mode (find directories) |
| `Ctrl+j` | Zoxide mode (recent directories) |
| `Ctrl+w` | Window mode (existing windows) |
| `Ctrl+n` | **Create new session** (with popup dialog) |
| `Ctrl+d` | **Delete session** (with confirmation) |
| `Ctrl+t` | Toggle / exit |

### Create Session Dialog

Press `Ctrl+n` to open a centered popup:
- Type session name (max 30 chars)
- Press `Enter` to create
- Press `Esc` to cancel
- Arrow keys and backspace supported

### Delete Session Dialog

Press `Ctrl+d` on a selected session:
- Use left/right arrows to select Yes/No
- Press `y` or `n` as shortcuts
- Press `Esc` to cancel
- Press `Enter` to confirm

## Configuration

```tmux
# Default command to run in new sessions
set -g @coffee-default-command "$EDITOR"

# Start in sessions mode (default: "zoxide")
set -g @coffee-default-mode "sessions"

# Default directory for find mode
set -g @coffee-find-path "$HOME/Projects"

# Preview position: "top", "bottom", "left", "right"
set -g @coffee-preview-position "top"
```

## Requirements

- tmux
- fzf
- zoxide
- fd (for directory search)
- eza (for directory previews)

## Author

**Hai Dinh Tuan** - me@haidinhtuan.de

## Credits

Based on [tmux-tea](https://github.com/2kabhishek/tmux-tea) by [2kabhishek](https://github.com/2kabhishek).

## License

MIT
