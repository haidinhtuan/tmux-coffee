#!/usr/bin/env bash
# Generate the footer status bar for tmux-coffee (Vim-style statusline)
# Usage: coffee-footer.sh MODE
# Uses $FZF_COLUMNS (set by coffee-draw-footer.sh) for exact footer width
#
# Layout: [MODE›SESSION›VPN›WINDOW›PANES)  ...gap...  (N sess‹M wins‹UPTIME]
# Powerline arrows (\ue0b0/\ue0b2) between segments, pill caps (\ue0b4/\ue0b6)
# at group edges.
# All segments always visible (empty space when data is missing, like Starship)

mode=$1

# Catppuccin Mocha mantle background: #181825 (RGB: 24, 24, 37)
MANTLE_BG='\033[48;2;24;24;37m'
RESET='\033[0m'

# Colors (Catppuccin Mocha pastel palette)
# Mode colors
COL_SESSIONS_R=164 COL_SESSIONS_G=197 COL_SESSIONS_B=255  # blue  #a4c5ff
COL_FIND_R=189 COL_FIND_G=240 COL_FIND_B=185              # green #bdf0b9
COL_ZOXIDE_R=168 COL_ZOXIDE_G=240 COL_ZOXIDE_B=229        # teal  #a8f0e5
COL_WINDOWS_R=245 COL_WINDOWS_G=194 COL_WINDOWS_B=231     # pink  #f5c2e7
# Segment colors
COL_SESSION_R=203 COL_SESSION_G=166 COL_SESSION_B=247     # mauve #cba6f7
COL_VPN_R=148 COL_VPN_G=226 COL_VPN_B=213                 # teal  #94e2d5
COL_STATS1_R=245 COL_STATS1_G=194 COL_STATS1_B=231        # pink  #f5c2e7
COL_STATS2_R=255 COL_STATS2_G=198 COL_STATS2_B=161        # peach #ffc6a1
COL_WINDOW_R=137 COL_WINDOW_G=220 COL_WINDOW_B=235       # sky   #89dceb
COL_PANES_R=242 COL_PANES_G=205 COL_PANES_B=205          # flamingo #f2cdcd
COL_UPTIME_R=180 COL_UPTIME_G=190 COL_UPTIME_B=254       # lavender #b4befe

# Mode -> pill color
case "$mode" in
    SESSIONS) mr=$COL_SESSIONS_R mg=$COL_SESSIONS_G mb=$COL_SESSIONS_B ;;
    FIND)     mr=$COL_FIND_R mg=$COL_FIND_G mb=$COL_FIND_B ;;
    ZOXIDE)   mr=$COL_ZOXIDE_R mg=$COL_ZOXIDE_G mb=$COL_ZOXIDE_B ;;
    WINDOWS)  mr=$COL_WINDOWS_R mg=$COL_WINDOWS_G mb=$COL_WINDOWS_B ;;
    *)        mr=$COL_SESSIONS_R mg=$COL_SESSIONS_G mb=$COL_SESSIONS_B ;;
esac

# Get current session and VPN (always show segment, empty if no data)
_cur_sess=$(tmux display-message -p '#S' 2>/dev/null)
_cur_vpn=$(tmux show-environment -t "$_cur_sess" SESSION_VPN 2>/dev/null | cut -d= -f2)
[[ -z "$_cur_vpn" || "$_cur_vpn" == "none" ]] && _cur_vpn=""

# Truncate session name if too long
[[ ${#_cur_sess} -gt 24 ]] && _cur_sess="${_cur_sess:0:22}.."

# Truncate VPN name if too long
[[ ${#_cur_vpn} -gt 10 ]] && _cur_vpn="${_cur_vpn:0:8}.."

# Window name and pane count
_cur_win=$(tmux display-message -p '#W' 2>/dev/null)
[[ ${#_cur_win} -gt 14 ]] && _cur_win="${_cur_win:0:12}.."
_n_panes=$(tmux list-panes -st "$_cur_sess" 2>/dev/null | wc -l | tr -d ' ')

# Server uptime
_start_time=$(tmux display-message -p '#{start_time}' 2>/dev/null)
if [[ -n "$_start_time" ]]; then
    _now=$(date +%s)
    _elapsed=$(( _now - _start_time ))
    if (( _elapsed >= 86400 )); then
        _up_d=$(( _elapsed / 86400 ))
        _up_h=$(( (_elapsed % 86400) / 3600 ))
        _uptime="${_up_d}d ${_up_h}h"
    elif (( _elapsed >= 3600 )); then
        _up_h=$(( _elapsed / 3600 ))
        _up_m=$(( (_elapsed % 3600) / 60 ))
        _uptime="${_up_h}h ${_up_m}m"
    else
        _up_m=$(( _elapsed / 60 ))
        _uptime="${_up_m}m"
    fi
else
    _uptime=""
fi

# Session & window counts
_n_sess=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
_n_wins=$(tmux list-windows -a 2>/dev/null | wc -l | tr -d ' ')

cols=${FZF_COLUMNS:-80}

# ============ LEFT GROUP: MODE › SESSION › VPN › WINDOW › PANES ============

mode_text=" $mode "
if [[ -n "$_cur_sess" ]]; then sess_text=" $_cur_sess "; else sess_text=" "; fi
if [[ -n "$_cur_vpn" ]]; then vpn_text=" $_cur_vpn "; else vpn_text=" "; fi
if [[ -n "$_cur_win" ]]; then win_text=" $_cur_win "; else win_text=" "; fi
if [[ -n "$_n_panes" && "$_n_panes" -gt 0 ]]; then
    _pane_label="pane"; (( _n_panes != 1 )) && _pane_label="panes"
    pane_text=" $_n_panes $_pane_label "
else
    pane_text=" "
fi

# Build left group (powerline arrows between segments, pill end)
left_output=""
left_visible_len=0
powerline_count=0

# Segment 1: MODE
left_output+=$(printf '\033[48;2;%d;%d;%dm\033[1;38;2;24;24;37m%s' "$mr" "$mg" "$mb" "$mode_text")
left_visible_len=$(( left_visible_len + ${#mode_text} ))

# Arrow: mode -> session
left_output+=$(printf '\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm\ue0b0' \
    "$mr" "$mg" "$mb" "$COL_SESSION_R" "$COL_SESSION_G" "$COL_SESSION_B")
powerline_count=$((powerline_count + 1))

# Segment 2: SESSION
left_output+=$(printf '\033[48;2;%d;%d;%dm\033[1;38;2;24;24;37m%s' \
    "$COL_SESSION_R" "$COL_SESSION_G" "$COL_SESSION_B" "$sess_text")
left_visible_len=$(( left_visible_len + ${#sess_text} ))

# Arrow: session -> vpn
left_output+=$(printf '\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm\ue0b0' \
    "$COL_SESSION_R" "$COL_SESSION_G" "$COL_SESSION_B" "$COL_VPN_R" "$COL_VPN_G" "$COL_VPN_B")
powerline_count=$((powerline_count + 1))

# Segment 3: VPN
left_output+=$(printf '\033[48;2;%d;%d;%dm\033[1;38;2;24;24;37m%s' \
    "$COL_VPN_R" "$COL_VPN_G" "$COL_VPN_B" "$vpn_text")
left_visible_len=$(( left_visible_len + ${#vpn_text} ))

# Arrow: vpn -> window
left_output+=$(printf '\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm\ue0b0' \
    "$COL_VPN_R" "$COL_VPN_G" "$COL_VPN_B" "$COL_WINDOW_R" "$COL_WINDOW_G" "$COL_WINDOW_B")
powerline_count=$((powerline_count + 1))

# Segment 4: WINDOW
left_output+=$(printf '\033[48;2;%d;%d;%dm\033[1;38;2;24;24;37m%s' \
    "$COL_WINDOW_R" "$COL_WINDOW_G" "$COL_WINDOW_B" "$win_text")
left_visible_len=$(( left_visible_len + ${#win_text} ))

# Arrow: window -> panes
left_output+=$(printf '\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm\ue0b0' \
    "$COL_WINDOW_R" "$COL_WINDOW_G" "$COL_WINDOW_B" "$COL_PANES_R" "$COL_PANES_G" "$COL_PANES_B")
powerline_count=$((powerline_count + 1))

# Segment 5: PANES
left_output+=$(printf '\033[48;2;%d;%d;%dm\033[1;38;2;24;24;37m%s' \
    "$COL_PANES_R" "$COL_PANES_G" "$COL_PANES_B" "$pane_text")
left_visible_len=$(( left_visible_len + ${#pane_text} ))

# Pill end: rounded right cap
left_output+=$(printf '%b\033[38;2;%d;%d;%dm\ue0b4' "$MANTLE_BG" "$COL_PANES_R" "$COL_PANES_G" "$COL_PANES_B")
powerline_count=$((powerline_count + 1))

# ============ RIGHT GROUP: SESSIONS ‹ WINDOWS ‹ UPTIME ============
_sess_label="session"; (( _n_sess != 1 )) && _sess_label="sessions"
_wins_label="window"; (( _n_wins != 1 )) && _wins_label="windows"
stats_sess_text=" $_n_sess $_sess_label "
stats_wins_text=" $_n_wins $_wins_label "
if [[ -n "$_uptime" ]]; then uptime_text=" $_uptime "; else uptime_text=" "; fi
right_visible_len=$(( ${#stats_sess_text} + ${#stats_wins_text} + ${#uptime_text} ))

# Padding: fzf 0.67+ uses rivo/uniseg which counts PUA glyphs as 1 col (correct).
total_powerline=$(( powerline_count + 3 ))  # +3 for right group: pill_start + 2 arrows
pad=$(( cols - left_visible_len - right_visible_len - total_powerline ))
(( pad < 0 )) && pad=0

# ============ OUTPUT ============
# Left group
printf '%b%b' "$MANTLE_BG" "$left_output"

# Padding (mantle background)
printf '%b%*s' "$MANTLE_BG" "$pad" ""

# Right group: pill start + segments with arrows
# Pill start: rounded left cap
printf '%b\033[38;2;%d;%d;%dm\ue0b6' "$MANTLE_BG" "$COL_STATS1_R" "$COL_STATS1_G" "$COL_STATS1_B"
# Sessions segment (pink)
printf '\033[48;2;%d;%d;%dm\033[1;38;2;24;24;37m%s' \
    "$COL_STATS1_R" "$COL_STATS1_G" "$COL_STATS1_B" "$stats_sess_text"
# Arrow: sessions <- windows (peach points into pink)
printf '\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm\ue0b2' \
    "$COL_STATS2_R" "$COL_STATS2_G" "$COL_STATS2_B" "$COL_STATS1_R" "$COL_STATS1_G" "$COL_STATS1_B"
# Windows segment (peach)
printf '\033[48;2;%d;%d;%dm\033[1;38;2;24;24;37m%s' \
    "$COL_STATS2_R" "$COL_STATS2_G" "$COL_STATS2_B" "$stats_wins_text"
# Arrow: windows <- uptime (lavender points into peach)
printf '\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm\ue0b2' \
    "$COL_UPTIME_R" "$COL_UPTIME_G" "$COL_UPTIME_B" "$COL_STATS2_R" "$COL_STATS2_G" "$COL_STATS2_B"
# Uptime segment (lavender) — reset at end (caller clears the line)
printf '\033[48;2;%d;%d;%dm\033[1;38;2;24;24;37m%s\033[0m' \
    "$COL_UPTIME_R" "$COL_UPTIME_G" "$COL_UPTIME_B" "$uptime_text"
