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
DIM='\033[2m'
RESET='\033[0m'

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

tput cnorm

[[ -z "$session_name" ]] && exit 0

# Sanitize
session_name=$(echo "$session_name" | tr ' .:' '_')

# Check if session already exists
if tmux has-session -t "$session_name" 2>/dev/null; then
    exit 0
fi

# Get default command from tmux option
default_command=$(tmux show-option -gqv @tea-default-command 2>/dev/null)

# Create session (don't attach, just create)
if [[ -n "$default_command" ]]; then
    tmux new-session -d -s "$session_name" -c "$HOME" "$default_command"
else
    tmux new-session -d -s "$session_name" -c "$HOME"
fi
