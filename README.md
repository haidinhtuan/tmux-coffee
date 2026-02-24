# tmux-coffee

> Forked from [tmux-tea](https://github.com/2kabhishek/tmux-tea) by [2kabhishek](https://github.com/2kabhishek)

A tmux session manager with VPN-aware session switching, beautiful UI, and enhanced session management.

## Features

- **Fuzzy Search**: fzf integration for intuitive session selection
- **Session Previews**: Visual previews of existing sessions and directory contents
- **Zoxide Integration**: Directory-based session creation with smart directory jumping
- **VPN Session Binding**: Associate sessions with VPN profiles (IONOS, UI VPN, or none)
- **Automatic VPN Switching**: Switching sessions automatically connects the correct VPN
- **Create Sessions**: Popup dialog to create new sessions with VPN selection (`Ctrl+n`)
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
| `Ctrl+n` | **Create new session** (with VPN selection) |
| `Ctrl+d` | **Delete session** (with confirmation) |
| `Ctrl+t` | Toggle / exit |

### Create Session Dialog

Press `Ctrl+n` to open a centered popup:
1. Type session name (max 30 chars), press `Enter`
2. Select VPN association (None / IONOS / UI VPN) with arrow keys, press `Enter`
3. VPN connects automatically via popup before the session is created

### VPN Session Switching

When you switch to a session, `vpn-switch.sh` runs automatically to:
- Connect the session's associated VPN if not already active
- Disconnect the current VPN if switching to a different one
- Skip switching if already on the correct VPN

VPN bindings are persisted in `~/.tmux/vpn-sessions.conf` and restored across tmux restarts.

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

# Keybinding to toggle coffee (default: "t")
set -g @coffee-bind "t"

# Alt keybinding (default: "C-t", set to "false" to disable)
set -g @coffee-alt-bind "C-t"
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
