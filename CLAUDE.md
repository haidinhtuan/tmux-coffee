# tmux-coffee

A tmux session manager plugin with integrated VPN profile support. Fork of [2kabhishek/tmux-tea](https://github.com/2kabhishek/tmux-tea).

## Architecture

- **Plugin entry**: `coffee.tmux` — registers keybindings and tmux hooks (session-created, client-session-changed, session-closed)
- **Main script**: `bin/coffee.sh` — fzf-based session picker with multiple modes (zoxide, fd, sessions, windows)
- **Session management**: `bin/coffee-{new,kill,list,rename}-session.sh` — TUI dialogs for CRUD operations
- **VPN subsystem**: `bin/vpn-*.sh` — per-session VPN profiles with auto-switching on session change

## Key Files

| File | Purpose |
|------|---------|
| `coffee.tmux` | TPM plugin init — binds keys, sets up hooks |
| `bin/coffee.sh` | Main fzf picker (modes: zoxide, fd, sessions, windows) |
| `bin/coffee-new-session.sh` | TUI: name input + VPN selection popup |
| `bin/coffee-kill-session.sh` | TUI: confirm-delete with session fallback |
| `bin/coffee-list-sessions.sh` | Rich session listing with metadata columns |
| `bin/coffee-rename-session.sh` | TUI: rename with VPN mapping update |
| `bin/vpn-config.sh` | INI parser for `vpn-profiles.conf` — sourced by all VPN scripts |
| `bin/vpn-switch.sh` | Auto-switch VPN on session change (lock-protected) |
| `bin/vpn-set.sh` | Manual VPN assignment via fzf |
| `bin/vpn-save.sh` | Persist session-VPN mapping to `~/.tmux/vpn-sessions.conf` |
| `bin/vpn-restore.sh` | Post-resurrect: restore env vars + connect current session VPN |
| `bin/vpn-restore-session.sh` | Per-session env restore on session-created hook |
| `bin/vpn-cleanup.sh` | Remove orphaned entries from vpn-sessions.conf |

## VPN Config

- **Profiles**: `~/.tmux/vpn-profiles.conf` (INI format, gitignored)
- **Session mappings**: `~/.tmux/vpn-sessions.conf` (auto-generated key=value)
- Profile fields: `connect`, `detect`, `disconnect`, `post_connect`, `popup_width`, `popup_height`, `connect_before_session`

## tmux Options

All options prefixed `@coffee-`:
- `@coffee-bind` / `@coffee-alt-bind` — keybindings (default: `t` / `C-t`)
- `@coffee-find-path` / `@coffee-max-depth` — fd search scope
- `@coffee-default-mode` — initial mode: `zoxide` (default), `sessions`, `find`
- `@coffee-session-name` — `basename` or `full-path`
- `@coffee-default-command` — command to run in new sessions
- `@coffee-vpn-config` — path to vpn-profiles.conf
- `@coffee-include-sessions` — show sessions in zoxide mode
- `@coffee-eza-options` — eza flags for directory preview

## Conventions

- All scripts are bash (`#!/usr/bin/env bash`)
- TUI dialogs use raw terminal escape codes (tput + ANSI) — no ncurses dependency
- VPN scripts resolve symlinks via `readlink -f` for stow/dotfile compatibility
- Session names sanitized: spaces, dots, colons replaced with underscores
- Lock files used to prevent concurrent VPN switching (`/tmp/tmux-vpn-switch.lock`)
- Temp files for inter-script communication (`/tmp/tmux-coffee-last-created`)
