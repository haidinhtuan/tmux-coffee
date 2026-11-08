#!/usr/bin/env bash
# Format directory candidates for the picker.
#
# Usage: <paths on stdin> | coffee-list-dirs.sh
#
# Output per line: "<~/parent/>\e[1m<name>\e[0m\t<marker>"
#   - parent path dimmed, folder name bold
#   - "● <session>" when a tmux session already uses that folder
# Field 1 (before TAB) stripped of ANSI is the path; callers use `cut -f1`.

map_file=$(mktemp)
trap 'rm -f "$map_file"' EXIT
tmux list-sessions -F '#{session_path}|#{session_name}' 2>/dev/null > "$map_file"

awk -v home="$HOME" -v map="$map_file" '
BEGIN {
    FS = "\n"
    while ((getline line < map) > 0) {
        i = index(line, "|")
        p = substr(line, 1, i - 1); n = substr(line, i + 1)
        if (p != home && !(p in sess)) sess[p] = n
    }
    DIM = "\033[38;2;127;132;156m"; BOLD = "\033[1;38;2;205;214;244m"
    GREEN = "\033[38;2;189;240;185m"; R = "\033[0m"
}
{
    path = $0
    sub(/\/$/, "", path)
    if (path == "") next
    full = path
    if (substr(full, 1, 2) == "~/") full = home substr(full, 2)
    shown = full
    if (index(shown, home "/") == 1) shown = "~" substr(shown, length(home) + 1)
    else if (shown == home) shown = "~"
    k = match(shown, /[^\/]*$/)
    parent = substr(shown, 1, k - 1); name = substr(shown, k)
    mark = (full in sess) ? GREEN "● " sess[full] R : ""
    printf "%s%s%s%s%s%s\t%s\n", DIM, parent, R, BOLD, name, R, mark
}'
