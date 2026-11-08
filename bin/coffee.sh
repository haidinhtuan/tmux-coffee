#!/usr/bin/env bash

BIN_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly DEFAULT_FIND_PATH="$HOME/Projects"
readonly DEFAULT_SHOW_NTH="-2,-1"
readonly DEFAULT_MAX_DEPTH="2"
readonly DEFAULT_PREVIEW_POSITION="auto"
readonly DEFAULT_LAYOUT="reverse"
readonly DEFAULT_SESSION_NAME_STYLE="basename"
readonly DEFAULT_FZF_TMUX_OPTIONS="-p 90%"

# Popup styling (like gopass, terminal, btm popups)
readonly POPUP_BORDER="rounded"
readonly POPUP_BORDER_COLOR="#f5c2e7"  # pink/mauve from Catppuccin
readonly POPUP_TITLE="  tmux-coffee  "
readonly DEFAULT_EZA_OPTIONS="-ahlT -L=2 -s=extension --group-directories-first --icons --git --git-ignore --no-user --color=always --color-scale=all --color-scale-mode=gradient"
readonly DEFAULT_INCLUDE_SESSIONS="true"
readonly DEFAULT_MODE="zoxide"

readonly PROMPT='  '
readonly MARKER=''
readonly HEADER=''

# Footer status bar rendered directly to terminal last line (bypasses fzf footer)
_footer_cmd="bash $BIN_DIR/coffee-draw-footer.sh"
_mode_file="/tmp/tmux-coffee-mode.$$"
# Window-stepping state for the session preview (see coffee-preview.sh)
_pwin_file="/tmp/tmux-coffee-pwin.$$"
echo 0 > "$_pwin_file"
# Session column header — must match printf format in coffee-list-sessions.sh exactly
# home path fix for sed
home_replacer=""
fzf_tmux_options=${FZF_TMUX_OPTS:-"$DEFAULT_FZF_TMUX_OPTIONS"}
[[ "$HOME" =~ ^[a-zA-Z0-9_/.@-]+$ ]] && home_replacer="s|^$HOME/|~/|"

# Cache tmux options for performance
TMUX_OPTIONS=$(tmux show-options -g | grep "^@coffee-")

get_tmux_option() {
    local option="$1"
    local default="$2"
    local value

    if [[ -n "$TMUX_OPTIONS" ]]; then
        value=$(echo "$TMUX_OPTIONS" | grep "^$option " | cut -d' ' -f2- | tr -d '"')
    fi

    echo "${value:-$default}"
}

find_path=$(get_tmux_option "@coffee-find-path" "$DEFAULT_FIND_PATH")
if [[ ! -d "$find_path" ]]; then
    find_path="~"
fi

show_nth=$(get_tmux_option "@coffee-show-nth" "$DEFAULT_SHOW_NTH")
max_depth=$(get_tmux_option "@coffee-max-depth" "$DEFAULT_MAX_DEPTH")
preview_position=$(get_tmux_option "@coffee-preview-position" "$DEFAULT_PREVIEW_POSITION")

# ---------- responsive layout ----------
# auto: side-by-side on wide terminals, stacked below SPLIT_AT columns
# (fzf re-evaluates the alternative on resize; a second <N() would be
# compared against the height once stacked, so keep a single one).
SPLIT_AT=160
if [[ "$preview_position" == "auto" ]]; then
    # fzf compares <N against the preview's own width (60% of the terminal),
    # so N = 60% of SPLIT_AT switches layouts at SPLIT_AT terminal columns.
    PREVIEW_WINDOW="right,60%,border-rounded,<$(( SPLIT_AT * 60 / 100 ))(down,50%,border-rounded)"
    SESSION_PREVIEW_WINDOW="$PREVIEW_WINDOW"
else
    PREVIEW_WINDOW="$preview_position"
    SESSION_PREVIEW_WINDOW="$preview_position,75%"
fi

# Popup size: a bit smaller on very wide (4K) clients, near full-screen otherwise
POPUP_W="95%"; POPUP_H="90%"
if [[ -n "$TMUX" ]]; then
    client_w=$(tmux display-message -p '#{client_width}' 2>/dev/null)
    client_w=${client_w:-$(tput cols)}
    (( client_w >= 250 )) && { POPUP_W="85%"; POPUP_H="80%"; }
    # width fzf will get inside the popup (minus border) — used by the session list
    COFFEE_COLUMNS=$(( client_w * ${POPUP_W%\%} / 100 - 2 ))
else
    COFFEE_COLUMNS=$(tput cols 2>/dev/null || echo 120)
fi
export COFFEE_COLUMNS
export COFFEE_SPLIT_AT=$SPLIT_AT
layout=$(get_tmux_option "@coffee-layout" "$DEFAULT_LAYOUT")
session_name_style=$(get_tmux_option "@coffee-session-name" "$DEFAULT_SESSION_NAME_STYLE")
default_command=$(get_tmux_option "@coffee-default-command" "")
eza_options=$(get_tmux_option "@coffee-eza-options" "$DEFAULT_EZA_OPTIONS")
include_sessions=$(get_tmux_option "@coffee-include-sessions" "$DEFAULT_INCLUDE_SESSIONS")
default_mode=$(get_tmux_option "@coffee-default-mode" "$DEFAULT_MODE")

# Initialize mode file so load/resize binds can read the current mode
case "$default_mode" in
    sessions) echo SESSIONS ;; find) echo FIND ;; *) echo ZOXIDE ;;
esac > "$_mode_file"

session_preview_cmd="tmux capture-pane -ep -t"
preview_script="bash $BIN_DIR/coffee-preview.sh"
dir_preview_cmd="$(which eza) ${eza_options}"
# Strip ANSI codes, then session marker prefix before preview
# Use actual ESC character for ANSI stripping (\x1b doesn't work in fzf's shell)
_esc=$'\x1b'
export COFFEE_EZA_OPTIONS="$eza_options"
preview="$preview_script {} $_pwin_file"

t_bind="ctrl-t:abort"
tab_bind="tab:down,btab:up"
list_sessions_cmd="bash $BIN_DIR/coffee-list-sessions.sh"
list_dirs_cmd="bash $BIN_DIR/coffee-list-dirs.sh"
SESSION_HEADER=$($list_sessions_cmd --header)
session_bind="ctrl-s:change-list-label( sessions )+change-prompt(  )+reload($list_sessions_cmd)+transform-header($list_sessions_cmd --header)+change-preview($preview_script {} $_pwin_file)+change-preview-window~$SESSION_PREVIEW_WINDOW~+execute-silent(echo SESSIONS > $_mode_file; $_footer_cmd SESSIONS)"
# Build zoxide_bind with proper quoting for sed and icons
_zoxide_sed="sed -e '"
_zoxide_sed+="$home_replacer"
_zoxide_sed+="'"
zoxide_bind='ctrl-j:change-list-label( recent folders )+change-prompt('"$PROMPT"')+reload(zoxide query -l | '"$list_dirs_cmd"')+change-header('"$HEADER"')+change-preview('"$preview_script"' {})+change-preview-window~'"$PREVIEW_WINDOW"'~+execute-silent(echo ZOXIDE > '"$_mode_file"'; '"$_footer_cmd"' ZOXIDE)'
fd_cmd="$(which fd 2>/dev/null || which fdfind 2>/dev/null || echo fd)"
find_bind="ctrl-f:change-list-label( find folders )+change-prompt(  )+reload($fd_cmd -H -d $max_depth -t d . $find_path | $list_dirs_cmd)+change-header($HEADER)+change-preview($preview_script {})+change-preview-window~$PREVIEW_WINDOW~+execute-silent(echo FIND > $_mode_file; $_footer_cmd FIND)"
window_bind="ctrl-w:change-list-label( windows )+change-prompt(  )+reload(tmux list-windows -a -F '#{session_name}:#{window_index}')+change-header($HEADER)+change-preview($preview_script {})+change-preview-window~$PREVIEW_WINDOW~+execute-silent(echo WINDOWS > $_mode_file; $_footer_cmd WINDOWS)"

delete_bind="ctrl-d:execute(bash $BIN_DIR/coffee-kill-session.sh \"\$(echo {} | sed -e 's/^● //' -e 's/^  //' | cut -f1 | sed 's/[[:space:]]*$//')\")+clear-screen+reload-sync($list_sessions_cmd)+execute-silent(echo SESSIONS > $_mode_file; $_footer_cmd SESSIONS)"
new_session_bind="ctrl-n:execute(bash $BIN_DIR/coffee-new-session.sh)+clear-screen+reload-sync($list_sessions_cmd)+execute-silent(echo SESSIONS > $_mode_file; $_footer_cmd SESSIONS)"
rename_bind="ctrl-r:execute(bash $BIN_DIR/coffee-rename-session.sh \"\$(echo {} | sed -e 's/^● //' -e 's/^  //' | cut -f1 | sed 's/[[:space:]]*$//')\")+clear-screen+reload-sync($list_sessions_cmd)+execute-silent(echo SESSIONS > $_mode_file; $_footer_cmd SESSIONS)"
resize_bind="resize:execute-silent($_footer_cmd \$(cat $_mode_file))"
clear_bind="ctrl-l:clear-screen+execute-silent($_footer_cmd \$(cat $_mode_file))"
preview_toggle_bind="ctrl-p:toggle-preview"
win_next_bind="alt-right:execute-silent($preview_script --step 1 $_pwin_file)+refresh-preview"
win_prev_bind="alt-left:execute-silent($preview_script --step -1 $_pwin_file)+refresh-preview"
drill_in_bind="right:transform(bash $BIN_DIR/coffee-drill.sh in $_mode_file $_pwin_file {q} {})"
drill_out_bind="left:transform(bash $BIN_DIR/coffee-drill.sh out $_mode_file $_pwin_file {q} {})"
win_reset_bind="focus:execute-silent($preview_script --step 0 $_pwin_file)+refresh-preview"
GHOST="type to filter  ·  → windows  ← back  ·  ^n new  ^r rename  ^d delete  ·  ^s sessions  ^j zoxide  ^f find  ·  ^p preview"

# determine if the tmux server is running
tmux_running=1
tmux list-sessions &>/dev/null && tmux_running=0

# determine the user's current position relative tmux:
run_type="serverless"
[[ "$tmux_running" -eq 0 ]] && run_type=$([[ "$TMUX" ]] && echo "attached" || echo "detached")

get_sessions_by_last_used() {
    bash "$BIN_DIR/coffee-list-sessions.sh" --no-current
}

get_zoxide_results() {
    zoxide query -l | $list_dirs_cmd
}

get_fzf_results() {
    if [[ "$tmux_running" -eq 0 ]]; then
        [[ "$include_sessions" == "true" ]] && sessions=$(get_sessions_by_last_used)
        [[ "$sessions" ]] && echo "$sessions" && get_zoxide_results || get_zoxide_results
    else
        get_zoxide_results
    fi
}

get_initial_results() {
    case "$default_mode" in
        sessions) bash "$BIN_DIR/coffee-list-sessions.sh" ;;
        find) $fd_cmd -H -d "$max_depth" -t d . "$find_path" | $list_dirs_cmd ;;
        *) get_fzf_results ;;
    esac
}

get_initial_prompt() {
    case "$default_mode" in
        sessions) echo '  ' ;;
        find) echo '  ' ;;
        *) echo "$PROMPT" ;;
    esac
}

get_initial_header() {
    case "$default_mode" in
        sessions) echo "$SESSION_HEADER" ;;
        *) echo "$HEADER" ;;
    esac
}

get_initial_list_label() {
    case "$default_mode" in
        sessions) echo ' sessions ' ;;
        find) echo ' find folders ' ;;
        *) echo ' recent folders ' ;;
    esac
}

get_initial_footer_bind() {
    echo "load:execute-silent($_footer_cmd \$(cat $_mode_file))"
}


create_and_attach_session() {
    local result="$1"
    local session_name

    zoxide add "$result" &>/dev/null

    if [[ $result != /* ]]; then # not a dir path
        session_name=$result
    else
        if [[ "$session_name_style" = "full-path" ]]; then
            session_name="${result/$HOME/\~}"
        else
            session_name=$(basename "$result")
        fi
        session_name=$(echo "$session_name" | tr ' .:' '_')
    fi

    if [[ "$run_type" = "serverless" ]] || ! tmux has-session -t="$session_name" &>/dev/null; then
        if [[ -e "$result"/.tmuxinator.yml ]] && command -v tmuxinator &>/dev/null; then
            cd "$result" && tmuxinator local
        elif [[ -e "$HOME/.config/tmuxinator/$session_name.yml" ]] && command -v tmuxinator &>/dev/null; then
            tmuxinator "$session_name"
        else
            if [[ -n "$default_command" ]]; then
                tmux new-session -d -s "$session_name" -c "$result" "$default_command"
            else
                tmux new-session -d -s "$session_name" -c "$result"
            fi
        fi
    fi

    # Open on the window that was being previewed (Alt+Left/Right)
    if [[ -f "$_pwin_file.sel" ]]; then
        IFS=$'\t' read -r _sel_sess _sel_idx < "$_pwin_file.sel"
        if [[ "$_sel_sess" == "$session_name" && -n "$_sel_idx" ]]; then
            tmux select-window -t "=$session_name:$_sel_idx" 2>/dev/null
        fi
    fi

    case $run_type in
    attached)
        tmux switch-client -t "$session_name"
        # Trigger VPN switch after session change (use run-shell for proper tmux context)
        tmux run-shell -b "$BIN_DIR/vpn-switch.sh '$session_name'"
        ;;
    detached | serverless) tmux attach -t "$session_name" ;;
    esac
}

show_help() {
    cat <<'EOF'
tmux-coffee - tmux sessions as easy as coffee

USAGE:
    coffee [OPTIONS] [DIRECTORY...]

OPTIONS:
    -h, --help      Show this help message

ARGUMENTS:
    DIRECTORY       One or more directories to open as tmux sessions
                    Can be absolute paths or zoxide queries

EXAMPLES:
    coffee                          # Interactive mode with fzf
    coffee ~/Projects/myapp         # Open session for ~/Projects/myapp
    coffee work personal            # Open multiple sessions using zoxide
    coffee ~/code/app1 ~/code/app2  # Open multiple sessions with paths

KEYBINDINGS (Interactive mode):
    Ctrl+f    Directory mode (find directories)
    Ctrl+j    Zoxide mode (recent directories)
    Ctrl+s    Session mode (existing sessions)
    Ctrl+w    Window mode (existing windows)
    Ctrl+d    Delete session (with confirmation)
    Ctrl+n    New session (name + VPN popup)
    Ctrl+r    Rename session
    Ctrl+t    Toggle coffee / exit

For more information, see: https://github.com/2kabhishek/tmux-coffee
EOF
}

validate_directory_arg() {
    local arg="$1"

    if [[ -d "$arg" ]]; then
        echo "$arg"
        return 0
    elif zoxide query "$arg" &>/dev/null; then
        zoxide query "$arg"
        return 0
    else
        echo "No directory found for: $arg" >&2
        return 1
    fi
}

process_single_session() {
    local result="$1"

    [[ $home_replacer ]] && result=$(echo "$result" | sed -e "s|^~/|$HOME/|")
    create_and_attach_session "$result"
}

process_argument() {
    local arg="$1"
    local result

    if result=$(validate_directory_arg "$arg"); then
        process_single_session "$result"
        return 0
    else
        return 1
    fi
}

if [[ $# -ge 1 ]]; then
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;
    esac

    if [[ $# -eq 1 ]]; then
        process_argument "$1" || exit 1
    else
        successful_sessions=0
        for arg in "$@"; do
            if process_argument "$arg"; then
                ((successful_sessions++))
            fi
        done

        if [[ $successful_sessions -eq 0 ]]; then
            echo "No valid directories found for any arguments." >&2
            exit 1
        fi
    fi
    exit 0
else
    case $run_type in
    attached)
        # Create temp files for input/output and fzf command
        tmp_dir=$(mktemp -d)
        input_file="$tmp_dir/input"
        output_file="$tmp_dir/output"
        fzf_cmd_file="$tmp_dir/fzf_cmd.sh"
        trap "rm -rf '$tmp_dir'; rm -f '$_mode_file' '$_pwin_file' '$_pwin_file.sel'" EXIT
        
        # Write initial results to temp file
        get_initial_results > "$input_file"
        touch "$output_file"
        
        # Write fzf options to file (one per line, using NUL as delimiter for safety)
        # This avoids complex quoting issues with heredocs
        {
            printf '%s\0' "--bind" "$preview_toggle_bind"
            printf '%s\0' "--bind" "$win_next_bind"
            printf '%s\0' "--bind" "$win_prev_bind"
            printf '%s\0' "--bind" "$win_reset_bind"
            printf '%s\0' "--bind" "$drill_in_bind"
            printf '%s\0' "--bind" "$drill_out_bind"
            printf '%s\0' "--ghost" "$GHOST"
            printf '%s\0' "--gutter" " "
            printf '%s\0' "--bind" "$(get_initial_footer_bind)"
            printf '%s\0' "--bind" "$find_bind"
            printf '%s\0' "--bind" "$session_bind"
            printf '%s\0' "--bind" "$tab_bind"
            printf '%s\0' "--bind" "$window_bind"
            printf '%s\0' "--bind" "$t_bind"
            printf '%s\0' "--bind" "$zoxide_bind"
            printf '%s\0' "--bind" "$delete_bind"
            printf '%s\0' "--bind" "$new_session_bind"
            printf '%s\0' "--bind" "$rename_bind"
            printf '%s\0' "--bind" "$resize_bind"
            printf '%s\0' "--bind" "$clear_bind"
            printf '%s\0' "--border" "none"
            printf '%s\0' "--no-scrollbar"
            printf '%s\0' "--header" "$(get_initial_header)"
            printf '%s\0' "--ansi"
            printf '%s\0' "--tabstop=1"
            printf '%s\0' "--no-sort"
            printf '%s\0' "--cycle"
            printf '%s\0' "--delimiter=\t"
            printf '%s\0' "--nth=1"
            printf '%s\0' "--list-border=rounded"
            printf '%s\0' "--list-label" "$(get_initial_list_label)"
            printf '%s\0' "--color=list-border:#585b70,preview-border:#585b70,list-label:#cba6f7:bold,header:#9399b2"
            printf '%s\0' "--keep-right"
            printf '%s\0' "--prompt" "$(get_initial_prompt)"
            printf '%s\0' "--marker" "$MARKER"
            printf '%s\0' "--preview" "$preview"
            printf '%s\0' "--preview-window=$SESSION_PREVIEW_WINDOW"
            printf '%s\0' "--layout=$layout"
        } > "$fzf_cmd_file"
        
        # Use tmux display-popup with border and title (like gopass, terminal, btm)
        # Pass all file paths as arguments since env vars don't transfer to popup subprocess
        # Note: shell-command must be a single string argument
        tmux display-popup -E -w "$POPUP_W" -h "$POPUP_H" \
            -b "$POPUP_BORDER" -S "fg=$POPUP_BORDER_COLOR" -T "$POPUP_TITLE" \
            "$BIN_DIR/coffee-popup.sh '$fzf_cmd_file' '$input_file' '$output_file'" || true
        
        # Read result from output file
        result=$(cat "$output_file" 2>/dev/null || true)
        ;;
    detached)
        _fzf_height=$(($(tput lines) - 1))
        trap "rm -f '$_mode_file' '$_pwin_file' '$_pwin_file.sel'; printf '\033[%d;1H\033[2K' \"\$(tput lines)\" > /dev/tty" EXIT
        result=$(get_initial_results | fzf \
            --bind "$(get_initial_footer_bind)" --bind "$find_bind" --bind "$session_bind" --bind "$tab_bind" --bind "$window_bind" --bind "$t_bind" \
            --bind "$zoxide_bind" --bind "$delete_bind" --bind "$new_session_bind" --bind "$rename_bind" \
            --bind "$resize_bind" --bind "$clear_bind" --bind "$preview_toggle_bind" --bind "$win_next_bind" --bind "$win_prev_bind" --bind "$win_reset_bind" --bind "$drill_in_bind" --bind "$drill_out_bind" --ghost "$GHOST" --gutter ' ' \
            --height="$_fzf_height" --border none --no-scrollbar --header "$(get_initial_header)" --ansi --tabstop=1 \
            --no-sort --cycle --delimiter='\t' --nth=1 --keep-right --prompt "$(get_initial_prompt)" --marker "$MARKER" \
            --list-border=rounded --list-label "$(get_initial_list_label)" \
            --color='list-border:#585b70,preview-border:#585b70,list-label:#cba6f7:bold,header:#9399b2' \
            --preview "$preview" --preview-window="$SESSION_PREVIEW_WINDOW" --layout="$layout" || true)
        ;;
    serverless)
        _fzf_height=$(($(tput lines) - 1))
        trap "rm -f '$_mode_file' '$_pwin_file' '$_pwin_file.sel'; printf '\033[%d;1H\033[2K' \"\$(tput lines)\" > /dev/tty" EXIT
        result=$(get_initial_results | fzf \
            --bind "$(get_initial_footer_bind)" --bind "$find_bind" --bind "$tab_bind" --bind "$zoxide_bind" --bind "$delete_bind" --bind "$new_session_bind" --bind "$rename_bind" --bind "$t_bind" \
            --bind "$resize_bind" --bind "$clear_bind" \
            --height="$_fzf_height" --border none --no-scrollbar --header "$(get_initial_header)" --ansi --tabstop=24 --no-sort --cycle --delimiter='\t' --nth=1 \
            --keep-right --prompt "$(get_initial_prompt)" --marker "$MARKER" --preview "$dir_preview_cmd {}" || true)
        ;;
    esac
fi

# Handle Ctrl+n: create new session from typed name
if [[ "$result" == NEW_SESSION:* ]]; then
    session_name=$(echo "${result#NEW_SESSION:}" | tr ' .:' '_')
    [[ -z "$session_name" ]] && exit 0
    if [[ -n "$default_command" ]]; then
        tmux new-session -d -s "$session_name" -c "$HOME" "$default_command"
    else
        tmux new-session -d -s "$session_name" -c "$HOME"
    fi
    case $run_type in
        attached) tmux switch-client -t "$session_name" ;;
        detached | serverless) tmux attach -t "$session_name" ;;
    esac
    exit 0
fi

[[ "$result" ]] || exit 0

# Drill-down selection: mode file holds "SESSWIN<TAB><session>", line = window
_mode=$(cat "$_mode_file" 2>/dev/null)
if [[ "$_mode" == SESSWIN$'\t'* ]]; then
    _sess="${_mode#*$'\t'}"
    _idx=$(printf '%s' "$result" | sed -e 's/^● //' -e 's/^  //' | cut -f1 | tr -dc '0-9')
    if [[ -n "$_idx" ]] && tmux has-session -t "=$_sess" 2>/dev/null; then
        tmux select-window -t "=$_sess:$_idx" 2>/dev/null
        case $run_type in
            attached)
                tmux switch-client -t "=$_sess"
                tmux run-shell -b "$BIN_DIR/vpn-switch.sh '$_sess'"
                ;;
            *) tmux attach -t "=$_sess" ;;
        esac
    fi
    exit 0
fi

# Strip session marker prefix (● or spaces) if present
result=$(echo "$result" | sed -e 's/^● //' -e 's/^  //')

# Extract session/path name (strip metadata after tab, if present)
result=$(printf '%s' "$result" | cut -f1 | sed 's/[[:space:]]*$//')

[[ $home_replacer ]] && result=$(echo "$result" | sed -e "s|^~/|$HOME/|")

if [[ "$result" == /* && -d "$result" ]]; then
    # Directory selected — open new session popup with name + VPN
    zoxide add "$result" &>/dev/null
    rm -f /tmp/tmux-coffee-last-created
    escaped_result=$(printf '%q' "$result")
    tmux display-popup -E -w 50 -h 20 \
        -b "$POPUP_BORDER" -S "fg=$POPUP_BORDER_COLOR" -T "  new session  " \
        "bash $BIN_DIR/coffee-new-session.sh $escaped_result"
    # Switch to the newly created session
    if [[ -f /tmp/tmux-coffee-last-created ]]; then
        session_name=$(cat /tmp/tmux-coffee-last-created)
        rm -f /tmp/tmux-coffee-last-created
        case $run_type in
            attached) tmux switch-client -t "$session_name" ;;
            detached | serverless) tmux attach -t "$session_name" ;;
        esac
    fi
else
    create_and_attach_session "$result"
fi
