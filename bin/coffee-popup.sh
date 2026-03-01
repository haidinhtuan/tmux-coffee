#!/usr/bin/env bash
# coffee-popup.sh - Run fzf in a styled tmux popup
# This script is called by coffee.sh to display fzf in a popup with border/title
#
# Usage: coffee-popup.sh <fzf_args_file> <input_file> <output_file>
#   fzf_args_file - file containing NUL-delimited fzf arguments
#   input_file - file containing input for fzf
#   output_file - file to write selected result

# Debug log
exec 2>/tmp/coffee-popup-debug.log
set -x

fzf_args_file="$1"
input_file="$2"
output_file="$3"

echo "fzf_args_file: $fzf_args_file" >&2
echo "input_file: $input_file" >&2
echo "output_file: $output_file" >&2

if [[ -z "$fzf_args_file" || ! -f "$fzf_args_file" ]]; then
    echo "Error: fzf_args_file not found: $fzf_args_file" >&2
    exit 1
fi

if [[ -z "$input_file" || ! -f "$input_file" ]]; then
    echo "Error: input_file not found: $input_file" >&2
    exit 1
fi

# Reserve last line for footer rendered outside fzf
fzf_height=$(($(tput lines) - 1))

# Clean up footer line on exit
cleanup_footer() {
    local lines
    lines=$(tput lines 2>/dev/null)
    printf '\033[%d;1H\033[2K' "$lines" > /dev/tty 2>/dev/null
}
trap cleanup_footer EXIT

# Read NUL-delimited arguments into array and run fzf
args=()
while IFS= read -r -d '' arg; do
    args+=("$arg")
    echo "Arg: $arg" >&2
done < "$fzf_args_file"

args+=("--height=$fzf_height")

echo "Running fzf with ${#args[@]} args" >&2
fzf "${args[@]}" < "$input_file" > "$output_file"
