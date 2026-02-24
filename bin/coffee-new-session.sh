#!/usr/bin/env bash

# Handle Ctrl+C and cleanup
cleanup() {
    tput cnorm
    exit 0
}
trap cleanup INT TERM

# Get terminal size
rows=$(tput lines)
cols=$(tput cols)

# Box dimensions (inner width = 38)
box_width=40
box_height=5

# Calculate center position
start_row=$(( (rows - box_height) / 2 ))
start_col=$(( (cols - box_width) / 2 ))

# Clear and hide cursor
clear
tput civis

# Function to move cursor
move() { printf '\033[%d;%dH' "$1" "$2"; }

# Colors
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
RESET='\033[0m'
REVERSE='\033[7m'

# Draw box - using printf %s to ensure exact spacing
# Inner width = 38 characters
move $start_row $start_col
printf "${BLUE}╭──────────────────────────────────────╮${RESET}"
move $((start_row + 1)) $start_col
printf "${BLUE}│${RESET}%13s${GREEN}New Session${RESET}%14s${BLUE}│${RESET}" "" ""
move $((start_row + 2)) $start_col
printf "${BLUE}├──────────────────────────────────────┤${RESET}"
move $((start_row + 3)) $start_col
printf "${BLUE}│${RESET}%-38s${BLUE}│${RESET}" "  Name:"
move $((start_row + 4)) $start_col
printf "${BLUE}╰──────────────────────────────────────╯${RESET}"

# Position cursor for input (after "Name: ")
input_col=$((start_col + 10))
move $((start_row + 3)) $input_col
tput cnorm

# Read with support for basic editing
session_name=""
cursor_pos=0
max_len=28

redraw_input() {
    move $((start_row + 3)) $input_col
    printf "%-28s" "$session_name"
    move $((start_row + 3)) $((input_col + cursor_pos))
}

while IFS= read -r -s -n1 char; do
    # Escape key
    if [[ "$char" == $'\e' ]]; then
        read -r -s -n1 -t 0.05 next
        if [[ -z "$next" ]]; then
            cleanup
        fi
        if [[ "$next" == "[" ]]; then
            read -r -s -n1 -t 0.05 arrow
            case "$arrow" in
                D) # Left arrow
                    [[ $cursor_pos -gt 0 ]] && ((cursor_pos--))
                    move $((start_row + 3)) $((input_col + cursor_pos))
                    ;;
                C) # Right arrow
                    [[ $cursor_pos -lt ${#session_name} ]] && ((cursor_pos++))
                    move $((start_row + 3)) $((input_col + cursor_pos))
                    ;;
            esac
        fi
        continue
    fi

    # Enter key
    if [[ -z "$char" ]]; then
        break
    fi

    # Backspace
    if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\b' ]]; then
        if [[ $cursor_pos -gt 0 ]]; then
            session_name="${session_name:0:cursor_pos-1}${session_name:cursor_pos}"
            ((cursor_pos--))
            redraw_input
        fi
        continue
    fi

    # Regular character (max length)
    if [[ ${#session_name} -lt $max_len ]] && [[ "$char" =~ [[:print:]] ]]; then
        session_name="${session_name:0:cursor_pos}${char}${session_name:cursor_pos}"
        ((cursor_pos++))
        redraw_input
    fi
done

[[ -z "$session_name" ]] && cleanup

# Sanitize
session_name=$(echo "$session_name" | tr ' .:' '_')

# Check if session already exists
if tmux has-session -t "$session_name" 2>/dev/null; then
    cleanup
fi

# ============ VPN SELECTION ============
tput civis

# VPN options
vpn_options=("None" "IONOS" "UI VPN")
selected=0

# Draw VPN selection box
draw_vpn_box() {
    clear
    local vpn_start_row=$(( (rows - 7) / 2 ))

    move $vpn_start_row $start_col
    printf "${BLUE}╭──────────────────────────────────────╮${RESET}"
    move $((vpn_start_row + 1)) $start_col
    printf "${BLUE}│${RESET}%13s${YELLOW}Select VPN${RESET}%15s${BLUE}│${RESET}" "" ""
    move $((vpn_start_row + 2)) $start_col
    printf "${BLUE}├──────────────────────────────────────┤${RESET}"

    for i in "${!vpn_options[@]}"; do
        move $((vpn_start_row + 3 + i)) $start_col
        if [[ $i -eq $selected ]]; then
            printf "${BLUE}│${REVERSE}  > %-34s${RESET}${BLUE}│${RESET}" "${vpn_options[$i]}"
        else
            printf "${BLUE}│${RESET}    %-34s${BLUE}│${RESET}" "${vpn_options[$i]}"
        fi
    done

    move $((vpn_start_row + 6)) $start_col
    printf "${BLUE}╰──────────────────────────────────────╯${RESET}"
    move $((vpn_start_row + 7)) $start_col
    printf "${DIM}  ↑/↓: navigate  Enter: select  Esc: cancel${RESET}"
}

draw_vpn_box

while IFS= read -r -s -n1 char; do
    if [[ "$char" == $'\e' ]]; then
        read -r -s -n1 -t 0.05 next
        if [[ -z "$next" ]]; then
            cleanup
        fi
        if [[ "$next" == "[" ]]; then
            read -r -s -n1 -t 0.05 arrow
            case "$arrow" in
                A) # Up arrow
                    [[ $selected -gt 0 ]] && ((selected--))
                    draw_vpn_box
                    ;;
                B) # Down arrow
                    [[ $selected -lt $((${#vpn_options[@]} - 1)) ]] && ((selected++))
                    draw_vpn_box
                    ;;
            esac
        fi
        continue
    fi

    # Enter key
    if [[ -z "$char" ]]; then
        break
    fi
done

selected_vpn="${vpn_options[$selected]}"

tput cnorm
clear

# Get default command from tmux option
default_command=$(tmux show-option -gqv @coffee-default-command 2>/dev/null)

# Helper: create the detached session
create_session() {
    if [[ -n "$default_command" ]]; then
        tmux new-session -d -s "$session_name" -c "$HOME" "$default_command"
    else
        tmux new-session -d -s "$session_name" -c "$HOME"
    fi
}

# Set VPN environment for the session and save to persistent config
case "$selected_vpn" in
    "IONOS")
        create_session
        tmux set-environment -t "$session_name" SESSION_VPN "IONOS"
        ~/.tmux/scripts/vpn-save.sh "$session_name" "IONOS"
        tmux display-popup -E -w 60 -h 10 -b rounded -T " 󰖂 Connecting to IONOS " \
            "zsh -ic 'vpn_ionos; sleep 2'"
        ;;
    "UI VPN")
        # Run VPN/OSUM popup BEFORE creating session so the default window's
        # shell picks up the correct SSH_AUTH_SOCK from tmux global environment
        tmux display-popup -E -w 60 -h 15 -b rounded -T " 󰖂 Connecting to UI VPN " \
            'zsh -ic "vpn_ui; sleep 2"'
        # Popup doesn't have $TMUX set, so vpn_ui can't set global env - do it here
        tmux set-environment -g SSH_AUTH_SOCK ~/.ssh/ssh_auth_sock
        # NOW create the session - default window's .zshrc will read the correct env
        create_session
        tmux set-environment -t "$session_name" SESSION_VPN "UI VPN"
        ~/.tmux/scripts/vpn-save.sh "$session_name" "UI VPN"
        ;;
    *)
        create_session
        tmux set-environment -t "$session_name" SESSION_VPN "none"
        ~/.tmux/scripts/vpn-save.sh "$session_name" "none"
        ;;
esac
