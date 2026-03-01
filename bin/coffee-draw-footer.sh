#!/usr/bin/env bash
# Render the footer status bar directly to the terminal's last line,
# bypassing fzf's footer rendering entirely.
# Usage: coffee-draw-footer.sh MODE

mode=$1
lines=$(tput lines </dev/tty 2>/dev/null)
cols=$(tput cols </dev/tty 2>/dev/null)
export FZF_COLUMNS="$cols"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
footer=$("$SCRIPT_DIR/coffee-footer.sh" "$mode")

{
    printf '\0337'                    # save cursor (DEC)
    printf '\033[%d;1H' "$lines"     # move to last line
    printf '\033[2K'                  # clear line
    printf '%b' "$footer"            # render
    printf '\033[0m'                  # reset attributes
    printf '\0338'                    # restore cursor (DEC)
} > /dev/tty
