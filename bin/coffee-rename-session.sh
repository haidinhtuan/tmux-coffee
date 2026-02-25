#!/usr/bin/env bash
# Rename an existing tmux session with a TUI dialog

session_to_rename="$1"
[[ -z "$session_to_rename" ]] && exit 1

# Handle Ctrl+C and cleanup
cleanup() {
    tput cnorm
    exit 0
}
trap cleanup INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.tmux/vpn-sessions.conf"

# Get terminal size
rows=$(tput lines)
cols=$(tput cols)

# Box dimensions (inner width = 38)
box_width=40
box_height=7

# Calculate center position
start_row=$(( (rows - box_height) / 2 ))
start_col=$(( (cols - box_width) / 2 ))

# Clear and hide cursor
tput clear
tput civis

# Function to move cursor
move() { printf '\033[%d;%dH' "$1" "$2"; }

# Colors
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
DIM='\033[2m'
RESET='\033[0m'

# Truncate display name if too long
display_name="${session_to_rename:0:24}"

# Draw box
move $start_row $start_col
printf "${BLUE}╭──────────────────────────────────────╮${RESET}"
move $((start_row + 1)) $start_col
printf "${BLUE}│${RESET}%12s${YELLOW}Rename Session${RESET}%12s${BLUE}│${RESET}" "" ""
move $((start_row + 2)) $start_col
printf "${BLUE}├──────────────────────────────────────┤${RESET}"
move $((start_row + 3)) $start_col
printf "${BLUE}│${RESET}  ${DIM}Old:${RESET} %-31s${BLUE}│${RESET}" "$display_name"
move $((start_row + 4)) $start_col
printf "${BLUE}│${RESET}%-38s${BLUE}│${RESET}" "  New:"
move $((start_row + 5)) $start_col
printf "${BLUE}╰──────────────────────────────────────╯${RESET}"
move $((start_row + 6)) $start_col
printf "${DIM}  Enter: confirm  Esc: cancel${RESET}"

# Position cursor for input (after "New: ")
input_col=$((start_col + 8))
move $((start_row + 4)) $input_col
tput cnorm

# Pre-fill with current name
session_name="$session_to_rename"
cursor_pos=${#session_name}
max_len=28

redraw_input() {
    move $((start_row + 4)) $input_col
    printf "%-28s" "$session_name"
    move $((start_row + 4)) $((input_col + cursor_pos))
}
redraw_input

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
                    move $((start_row + 4)) $((input_col + cursor_pos))
                    ;;
                C) # Right arrow
                    [[ $cursor_pos -lt ${#session_name} ]] && ((cursor_pos++))
                    move $((start_row + 4)) $((input_col + cursor_pos))
                    ;;
            esac
        fi
        continue
    fi

    # Enter key
    if [[ -z "$char" ]]; then
        break
    fi

    # Ctrl+U: clear input
    if [[ "$char" == $'\x15' ]]; then
        session_name=""
        cursor_pos=0
        redraw_input
        continue
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

tput cnorm

# Sanitize
session_name=$(echo "$session_name" | tr ' .:' '_')

# Validate
[[ -z "$session_name" ]] && cleanup
[[ "$session_name" == "$session_to_rename" ]] && exit 0

# Check if target name already exists
if tmux has-session -t "$session_name" 2>/dev/null; then
    tput civis
    move $((start_row + 6)) $start_col
    printf "\033[1;31m  Session '%s' already exists!${RESET}      " "${session_name:0:18}"
    sleep 1.5
    tput cnorm
    exit 1
fi

# Rename the tmux session
tmux rename-session -t "$session_to_rename" "$session_name"

# Update VPN mapping if one exists
if [[ -f "$CONFIG_FILE" ]]; then
    old_vpn=$(grep "^${session_to_rename}=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    if [[ -n "$old_vpn" ]]; then
        # Remove old entry
        grep -v "^${session_to_rename}=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        # Add with new name
        echo "${session_name}=${old_vpn}" >> "$CONFIG_FILE"
        # Update tmux environment
        tmux set-environment -t "$session_name" SESSION_VPN "$old_vpn"
    fi
fi
