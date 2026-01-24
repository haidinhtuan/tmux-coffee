#!/usr/bin/env bash

session_to_kill="$1"
[[ -z "$session_to_kill" ]] && exit 1

# Get current session before killing
current_session=$(tmux display-message -p '#S' 2>/dev/null)

# Handle Ctrl+C and cleanup
cleanup() {
    tput cnorm
    exit 0
}
trap cleanup INT TERM

# Get terminal size
rows=$(tput lines)
cols=$(tput cols)

# Box dimensions
box_width=40
box_height=5

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
RED='\033[1;31m'
GREEN='\033[1;32m'
DIM='\033[2m'
RESET='\033[0m'

# Truncate session name if too long
display_name="${session_to_kill:0:20}"

# Draw box
move $start_row $start_col
printf "${BLUE}╭──────────────────────────────────────╮${RESET}"
move $((start_row + 1)) $start_col
printf "${BLUE}│${RESET}%12s${RED}Delete Session${RESET}%12s${BLUE}│${RESET}" "" ""
move $((start_row + 2)) $start_col
printf "${BLUE}├──────────────────────────────────────┤${RESET}"
move $((start_row + 3)) $start_col
printf "${BLUE}│${RESET}%-38s${BLUE}│${RESET}" "  Delete '$display_name'?"
move $((start_row + 4)) $start_col
printf "${BLUE}╰──────────────────────────────────────╯${RESET}"

# Selection
selected=1  # 1=Yes, 0=No

draw_options() {
    move $((start_row + 6)) $((start_col + 10))
    if [[ $selected -eq 1 ]]; then
        printf "${GREEN}▸ Yes${RESET}     ${DIM}No${RESET}  "
    else
        printf "${DIM}  Yes${RESET}   ${GREEN}▸ No${RESET}  "
    fi
}

draw_options
tput cnorm

# Handle input
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
                D|C) # Left/Right arrow - toggle
                    selected=$((1 - selected))
                    draw_options
                    ;;
            esac
        fi
        continue
    fi

    # Enter key
    if [[ -z "$char" ]]; then
        break
    fi

    # y/Y for yes
    if [[ "$char" == "y" ]] || [[ "$char" == "Y" ]]; then
        selected=1
        break
    fi

    # n/N for no
    if [[ "$char" == "n" ]] || [[ "$char" == "N" ]]; then
        selected=0
        break
    fi
done

tput cnorm

# If No selected, exit
[[ $selected -eq 0 ]] && exit 0

# Kill the session
tmux kill-session -t "$session_to_kill" 2>/dev/null

# If we killed the current session, switch to another one
if [[ "$session_to_kill" == "$current_session" ]]; then
    new_session=$(tmux list-sessions -F '#S' 2>/dev/null | head -1)
    if [[ -n "$new_session" ]]; then
        tmux switch-client -t "$new_session" 2>/dev/null
    fi
fi
