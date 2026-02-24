#!/usr/bin/env bash

# Handle Ctrl+C and cleanup
cleanup() {
    tput cnorm
    exit 0
}
trap cleanup INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vpn-config.sh"
target_dir="$1"

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
if [[ -n "$target_dir" ]]; then
    session_name=$(basename "$target_dir" | tr ' .:' '_')
    cursor_pos=${#session_name}
else
    session_name=""
    cursor_pos=0
fi
max_len=28

redraw_input() {
    move $((start_row + 3)) $input_col
    printf "%-28s" "$session_name"
    move $((start_row + 3)) $((input_col + cursor_pos))
}
[[ -n "$session_name" ]] && redraw_input

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

# Get default command from tmux option
default_command=$(tmux show-option -gqv @coffee-default-command 2>/dev/null)

# Helper: create the detached session
create_session() {
    local session_dir="${target_dir:-$HOME}"
    if [[ -n "$default_command" ]]; then
        tmux new-session -d -s "$session_name" -c "$session_dir" "$default_command"
    else
        tmux new-session -d -s "$session_name" -c "$session_dir"
    fi
    # Signal session name to caller (coffee.sh reads this after popup closes)
    if [[ -n "$target_dir" ]]; then
        echo "$session_name" > /tmp/tmux-coffee-last-created
    fi
}

# ============ VPN SELECTION ============

if [[ ${#VPN_NAMES[@]} -eq 0 ]]; then
    # No VPN profiles — just create session
    create_session
    tmux set-environment -t "$session_name" SESSION_VPN "none"
    "$SCRIPT_DIR/vpn-save.sh" "$session_name" "none"
    exit 0
fi

tput civis

# VPN options
vpn_options=("None" "${VPN_NAMES[@]}")
selected=0

# Draw VPN selection box
draw_vpn_box() {
    clear
    local vpn_box_height=$((4 + ${#vpn_options[@]}))
    local vpn_start_row=$(( (rows - vpn_box_height) / 2 ))

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

    move $((vpn_start_row + 3 + ${#vpn_options[@]})) $start_col
    printf "${BLUE}╰──────────────────────────────────────╯${RESET}"
    move $((vpn_start_row + 4 + ${#vpn_options[@]})) $start_col
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

if [[ "$selected_vpn" == "None" ]]; then
    create_session
    tmux set-environment -t "$session_name" SESSION_VPN "none"
    "$SCRIPT_DIR/vpn-save.sh" "$session_name" "none"
else
    if [[ "${VPN_CONNECT_BEFORE[$selected_vpn]}" == "true" ]]; then
        # Connect VPN BEFORE creating session (so shell picks up correct env)
        vpn_popup_connect "$selected_vpn"
        create_session
        tmux set-environment -t "$session_name" SESSION_VPN "$selected_vpn"
        "$SCRIPT_DIR/vpn-save.sh" "$session_name" "$selected_vpn"
    else
        create_session
        tmux set-environment -t "$session_name" SESSION_VPN "$selected_vpn"
        "$SCRIPT_DIR/vpn-save.sh" "$session_name" "$selected_vpn"
        vpn_popup_connect "$selected_vpn"
    fi
fi
