#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
label=com.keyboardswitcher
domain="gui/$(id -u)"
service="$domain/$label"
agent_dir="$HOME/Library/LaunchAgents"
plist="$agent_dir/$label.plist"
executable=/Applications/KeyboardSwitcher.app/Contents/MacOS/KeyboardSwitcher

if [ ! -x "$executable" ]; then
    printf '%s\n' 'Install KeyboardSwitcher.app in /Applications first.' >&2
    exit 1
fi

mkdir -p "$agent_dir"
install -m 644 "$script_dir/$label.plist" "$plist"

launchctl enable "$service"
if launchctl print "$service" >/dev/null 2>&1; then
    launchctl bootout "$service"
fi
launchctl bootstrap "$domain" "$plist"
