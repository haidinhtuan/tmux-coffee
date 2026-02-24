#!/usr/bin/env bash

readonly DEFAULT_FIND_PATH="$HOME/Projects"
readonly DEFAULT_SHOW_NTH="-2,-1"
readonly DEFAULT_MAX_DEPTH="2"
readonly DEFAULT_PREVIEW_POSITION="top"
readonly DEFAULT_LAYOUT="reverse"
readonly DEFAULT_SESSION_NAME_STYLE="basename"
readonly DEFAULT_FZF_TMUX_OPTIONS="-p 90%"
readonly DEFAULT_EZA_OPTIONS="-ahlT -L=2 -s=extension --group-directories-first --icons --git --git-ignore --no-user --color=always --color-scale=all --color-scale-mode=gradient"
readonly DEFAULT_INCLUDE_SESSIONS="true"
readonly DEFAULT_MODE="zoxide"

readonly PROMPT='  '
readonly MARKER=''
readonly BORDER_LABEL='   tmux-coffee   '
readonly HEADER='^f 󰉋  ^j 󰔠  ^s 󰝰  ^w 󱂬  ^d 󰗨  ^n 󰐕'
# Session column header — uses same icons and printf widths as coffee-list-sessions.sh
SESSION_COLS=$(printf '  %s\t   %s   %s   %s   %s   %s' \
    'SESSION' "$(printf ' %-3s' '#')" "$(printf '󰖟 %-12s' 'VPN')" "$(printf '󰉋 %-28s' 'DIR')" "$(printf ' %-10s' 'CMD')" "$(printf ' %s' 'LAST ACTIVE')")
readonly SESSION_HEADER="$HEADER
$SESSION_COLS"
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
layout=$(get_tmux_option "@coffee-layout" "$DEFAULT_LAYOUT")
session_name_style=$(get_tmux_option "@coffee-session-name" "$DEFAULT_SESSION_NAME_STYLE")
default_command=$(get_tmux_option "@coffee-default-command" "")
eza_options=$(get_tmux_option "@coffee-eza-options" "$DEFAULT_EZA_OPTIONS")
include_sessions=$(get_tmux_option "@coffee-include-sessions" "$DEFAULT_INCLUDE_SESSIONS")
default_mode=$(get_tmux_option "@coffee-default-mode" "$DEFAULT_MODE")

session_preview_cmd="tmux capture-pane -ep -t"
dir_preview_cmd="$(which eza) ${eza_options}"
# Strip session marker prefix before preview
preview="target=\$(echo {} | sed -e 's/^● //' -e 's/^  //' | cut -f1); $session_preview_cmd \"\$target\" 2>/dev/null || eval $dir_preview_cmd \"\$target\""

t_bind="ctrl-t:abort"
tab_bind="tab:down,btab:up"
list_sessions_cmd="bash $HOME/.tmux/plugins/tmux-coffee/bin/coffee-list-sessions.sh"
session_bind="ctrl-s:change-prompt(  )+reload($list_sessions_cmd)+change-header($SESSION_HEADER)+change-preview-window($preview_position,85%)"
zoxide_bind="ctrl-j:change-prompt(  )+reload(zoxide query -l | sed -e \"$home_replacer\")+change-header($HEADER)+change-preview(eval $dir_preview_cmd {})+change-preview-window(right)"
fd_cmd="$(which fd 2>/dev/null || which fdfind 2>/dev/null || echo fd)"
find_bind="ctrl-f:change-prompt(  )+reload($fd_cmd -H -d $max_depth -t d . $find_path | sed 's|/$||')+change-header($HEADER)+change-preview($dir_preview_cmd {})+change-preview-window(right)"
window_bind="ctrl-w:change-prompt(  )+reload(tmux list-windows -a -F '#{session_name}:#{window_index}')+change-header($HEADER)+change-preview($session_preview_cmd {})+change-preview-window($preview_position)"

delete_bind="ctrl-d:execute(bash $HOME/.tmux/plugins/tmux-coffee/bin/coffee-kill-session.sh \$(echo {} | sed -e 's/^● //' -e 's/^  //' | cut -f1))+reload-sync($list_sessions_cmd)"
new_session_bind="ctrl-n:execute(bash $HOME/.tmux/plugins/tmux-coffee/bin/coffee-new-session.sh)+reload-sync($list_sessions_cmd)"

# determine if the tmux server is running
tmux_running=1
tmux list-sessions &>/dev/null && tmux_running=0

# determine the user's current position relative tmux:
run_type="serverless"
[[ "$tmux_running" -eq 0 ]] && run_type=$([[ "$TMUX" ]] && echo "attached" || echo "detached")

get_sessions_by_last_used() {
    bash "$HOME/.tmux/plugins/tmux-coffee/bin/coffee-list-sessions.sh" --no-current
}

get_zoxide_results() {
    zoxide query -l | sed -e "$home_replacer"
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
        sessions) bash "$HOME/.tmux/plugins/tmux-coffee/bin/coffee-list-sessions.sh" ;;
        find) $fd_cmd -H -d "$max_depth" -t d . "$find_path" | sed 's|/$||' ;;
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

    case $run_type in
    attached)
        tmux switch-client -t "$session_name"
        # Trigger VPN switch after session change (use run-shell for proper tmux context)
        tmux run-shell -b "$HOME/.tmux/plugins/tmux-coffee/bin/vpn-switch.sh '$session_name'"
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
        result=$(get_initial_results | fzf-tmux \
            --bind "$find_bind" --bind "$session_bind" --bind "$tab_bind" --bind "$window_bind" --bind "$t_bind" \
            --bind "$zoxide_bind" --bind "$delete_bind" --bind "$new_session_bind" \
            --border-label "$BORDER_LABEL" --header "$(get_initial_header)" --ansi --tabstop=24 \
            --no-sort --cycle --delimiter='/' --with-nth="$show_nth" --keep-right --prompt "$(get_initial_prompt)" --marker "$MARKER" \
            --preview "$preview" --preview-window="$preview_position",75% "$fzf_tmux_options" --layout="$layout" || true)
        ;;
    detached)
        result=$(get_initial_results | fzf \
            --bind "$find_bind" --bind "$session_bind" --bind "$tab_bind" --bind "$window_bind" --bind "$t_bind" \
            --bind "$zoxide_bind" --bind "$delete_bind" --bind "$new_session_bind" \
            --border-label "$BORDER_LABEL" --header "$(get_initial_header)" --ansi --tabstop=24 \
            --no-sort --cycle --delimiter='/' --with-nth="$show_nth" --keep-right --prompt "$(get_initial_prompt)" --marker "$MARKER" \
            --preview "$preview" --preview-window=top,75% || true)
        ;;
    serverless)
        result=$(get_initial_results | fzf \
            --bind "$find_bind" --bind "$tab_bind" --bind "$zoxide_bind" --bind "$delete_bind" --bind "$new_session_bind" --bind "$t_bind" \
            --border-label "$BORDER_LABEL" --header "$(get_initial_header)" --ansi --tabstop=24 --no-sort --cycle --delimiter='/' --with-nth="$show_nth" \
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

# Strip session marker prefix (● or spaces) if present
result=$(echo "$result" | sed -e 's/^● //' -e 's/^  //')

# Extract session/path name (strip metadata after tab, if present)
result=$(printf '%s' "$result" | cut -f1)

[[ $home_replacer ]] && result=$(echo "$result" | sed -e "s|^~/|$HOME/|")

if [[ "$result" == /* && -d "$result" ]]; then
    # Directory selected — open new session popup with name + VPN
    zoxide add "$result" &>/dev/null
    rm -f /tmp/tmux-coffee-last-created
    escaped_result=$(printf '%q' "$result")
    tmux display-popup -E -w 50 -h 20 \
        "bash $HOME/.tmux/plugins/tmux-coffee/bin/coffee-new-session.sh $escaped_result"
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
