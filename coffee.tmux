#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmux_option_or_fallback() {
    local option_value
    option_value="$(tmux show-option -gqv "$1")"
    if [ -z "$option_value" ]; then
        option_value="$2"
    fi
    echo "$option_value"
}

tmux bind-key "$(tmux_option_or_fallback "@coffee-bind" "t")" run-shell "$CURRENT_DIR/bin/coffee.sh"

ALT_KEY_BIND="$(tmux_option_or_fallback "@coffee-alt-bind" "C-t")"
if [ "$ALT_KEY_BIND" != "false" ]; then
    tmux bind-key -n "$ALT_KEY_BIND" run-shell "$CURRENT_DIR/bin/coffee.sh"
fi

# VPN configuration
if [ -z "$(tmux show-option -gqv @coffee-vpn-config)" ]; then
    tmux set-option -g @coffee-vpn-config "$HOME/.tmux/vpn-profiles.conf"
fi

# VPN hooks — only register if config file exists
vpn_config="$(tmux_option_or_fallback "@coffee-vpn-config" "$HOME/.tmux/vpn-profiles.conf")"
if [ -f "$vpn_config" ]; then
    tmux set-hook -g session-created "run-shell -b '$CURRENT_DIR/bin/vpn-restore-session.sh #{hook_session_name}'"
    tmux set-hook -g client-session-changed "run-shell '$CURRENT_DIR/bin/vpn-switch.sh #{session_name}'"
    tmux set-hook -g session-closed "run-shell -b '$CURRENT_DIR/bin/vpn-cleanup.sh'"
fi
