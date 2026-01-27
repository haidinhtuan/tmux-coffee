#!/usr/bin/env bash
# List tmux sessions with current session highlighted

current_session=$(tmux display-message -p '#S' 2>/dev/null)

tmux list-sessions -F '#S' 2>/dev/null | while read -r session; do
    if [[ "$session" == "$current_session" ]]; then
        # Highlight current session with green color and marker
        echo -e "\033[1;32m● $session\033[0m"
    else
        echo "  $session"
    fi
done
