#!/bin/bash
input=$(cat)

WIDTH=25

GREEN_END=10
YELLOW_END=18

# Drift threshold (percentage points) for the time marker's color: how far
# ahead/behind of the clock counts as "comfortable" (green) vs "tight"
# (red), with anything closer than that in yellow. Overridable via
# $XDG_CONFIG_HOME/claude-code-limits-statusline/config (falls back to
# ~/.config/... if XDG_CONFIG_HOME is unset), a plain shell-sourced file
# setting DRIFT_THRESHOLD=<n>.
DRIFT_THRESHOLD=10
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/claude-code-limits-statusline/config"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

bar() {
    local pct=$1
    local time_pct=$2
    local filled=$(( (pct * WIDTH + 50) / 100 ))
    (( filled > WIDTH )) && filled=$WIDTH
    (( filled < 0 )) && filled=0

    local marker=-1
    if [ -n "$time_pct" ]; then
        marker=$(( (time_pct * WIDTH + 50) / 100 ))
        (( marker >= WIDTH )) && marker=$((WIDTH - 1))
        (( marker < 0 )) && marker=0
    fi

    local marker_fg=$'\033[97m'
    if [ -n "$time_pct" ]; then
        local diff=$(( time_pct - pct ))
        if (( diff > DRIFT_THRESHOLD )); then
            marker_fg=$'\033[32m'
        elif (( diff < -DRIFT_THRESHOLD )); then
            marker_fg=$'\033[31m'
        else
            marker_fg=$'\033[93m'
        fi
    fi

    local out="" i fg bg
    for (( i=0; i<WIDTH; i++ )); do
        if (( i < filled )); then
            if (( i < GREEN_END )); then
                fg=$'\033[32m'; bg=$'\033[42m'
            elif (( i < YELLOW_END )); then
                fg=$'\033[93m'; bg=$'\033[103m'
            else
                fg=$'\033[31m'; bg=$'\033[41m'
            fi
        else
            fg=$'\033[90m'; bg=$'\033[100m'
        fi
        if (( i == marker )); then
            out+="${marker_fg}""${bg}"'▀'$'\033[0m'
        else
            out+="${fg}"'▄'$'\033[0m'
        fi
    done
    printf '%s' "$out"
}

time_pct() {
    local resets_at=$1
    local window_secs=$2
    [ -z "$resets_at" ] && return
    local now remaining
    now=$(date +%s)
    remaining=$(( resets_at - now ))
    (( remaining < 0 )) && remaining=0
    (( remaining > window_secs )) && remaining=$window_secs
    echo $(( (window_secs - remaining) * 100 / window_secs ))
}

remaining_secs() {
    local resets_at=$1
    [ -z "$resets_at" ] && return
    local now remaining
    now=$(date +%s)
    remaining=$(( resets_at - now ))
    (( remaining < 0 )) && remaining=0
    echo "$remaining"
}

countdown_7d() {
    local remaining=$1
    [ -z "$remaining" ] && return
    local days=$(( remaining / 86400 ))
    local hours=$(( (remaining % 86400) / 3600 ))
    local mins=$(( (remaining % 3600) / 60 ))
    printf '%d/%02d:%02d' "$days" "$hours" "$mins"
}

countdown_5h() {
    local remaining=$1
    [ -z "$remaining" ] && return
    local hours=$(( remaining / 3600 ))
    local mins=$(( (remaining % 3600) / 60 ))
    printf '%d:%02d' "$hours" "$mins"
}

MODEL=$(echo "$input" | jq -r '.model.display_name')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
RESETS_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RESETS_WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

WEEK_TOTAL_SECS=$(( 7 * 24 * 3600 ))
FIVEH_TOTAL_SECS=$(( 5 * 3600 ))

LIMITS=""
if [ -n "$WEEK" ]; then
    PCT=$(printf '%.0f' "$WEEK")
    WEEK_REMAINING=$(remaining_secs "$RESETS_WEEK")
    WEEK_TIME_PCT=$(time_pct "$RESETS_WEEK" "$WEEK_TOTAL_SECS")
    LIMITS=$'\033[1;37m'"7d"$'\033[0m'">$(countdown_7d "$WEEK_REMAINING") ${PCT}% $(bar "$PCT" "$WEEK_TIME_PCT")"
fi
if [ -n "$FIVE_H" ]; then
    PCT=$(printf '%.0f' "$FIVE_H")
    FIVEH_REMAINING=$(remaining_secs "$RESETS_5H")
    FIVEH_TIME_PCT=$(time_pct "$RESETS_5H" "$FIVEH_TOTAL_SECS")
    LIMITS="${LIMITS:+$LIMITS  }"$'\033[1;37m'"5h"$'\033[0m'">$(countdown_5h "$FIVEH_REMAINING") ${PCT}% $(bar "$PCT" "$FIVEH_TIME_PCT")"
fi

WHITE_MODEL=$'\033[37m'"$MODEL"$'\033[0m'
[ -n "$LIMITS" ] && echo "$WHITE_MODEL:  $LIMITS" || echo "$WHITE_MODEL"
