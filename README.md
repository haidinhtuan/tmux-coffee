# tmux-coffee

> Forked from [tmux-tea](https://github.com/2kabhishek/tmux-tea) by [2kabhishek](https://github.com/2kabhishek)

A tmux session manager with VPN-aware session switching, beautiful UI, and enhanced session management.

## Features

- **Fuzzy Search**: fzf integration for intuitive session selection
- **Session Previews**: Visual previews of existing sessions and directory contents
- **Zoxide Integration**: Directory-based session creation with smart directory jumping
- **VPN Session Binding**: Associate sessions with configurable VPN profiles
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
2. Select VPN profile (from config) with arrow keys, press `Enter`
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

## VPN Configuration

VPN profiles are defined in an INI-style config file at `~/.tmux/vpn-profiles.conf` (override with `set -g @coffee-vpn-config /path/to/file`).

### Profile Format

```ini
[Profile Name]
connect = command to run in tmux popup to connect
detect = command that exits 0 when this VPN is active
disconnect = command to disconnect this VPN
post_connect = command to run after successful connection (optional)
popup_width = popup width in columns (default: 60)
popup_height = popup height in rows (default: 10)
connect_before_session = true to connect VPN before creating session (default: false)
```

### Example

```ini
[Work VPN]
connect = sudo openconnect vpn.example.com
detect = pgrep -f openconnect >/dev/null 2>&1
disconnect = sudo pkill openconnect
post_connect = tmux set-environment -g SSH_AUTH_SOCK ~/.ssh/agent.sock
popup_width = 60
popup_height = 15
connect_before_session = true
```

### Graceful Degradation

If no config file exists or it contains no profiles, all VPN features are silently disabled. The plugin works normally for session management without any VPN-related UI or hooks.

## Requirements

- tmux
- fzf
- zoxide
- fd (for directory search)
- eza (for directory previews)

## Credits

Based on [tmux-tea](https://github.com/2kabhishek/tmux-tea) by [2kabhishek](https://github.com/2kabhishek).

## License

MIT
