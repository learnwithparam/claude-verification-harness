#!/usr/bin/env bash
# Three Claudes on three tickets, and a fourth pane that prints every verdict as it lands.
set -eu
cd "$(dirname "$0")/.."
command -v tmux >/dev/null || { echo "tmux is not installed: run 'bash harness/try.sh 01' (02, 03) in three terminals instead."; exit 1; }
session=harness
tmux kill-session -t "$session" 2>/dev/null || true
log="$(git rev-parse --path-format=absolute --git-common-dir)/harness-verdicts.log"
touch "$log"
# A running tmux server keeps its own environment, so the settings travel with each command.
run="env MODEL='${MODEL:-sonnet}' CLAUDE_FLAGS='${CLAUDE_FLAGS:-}' bash harness/try.sh"
# Pane ids, not indexes, so a tmux.conf with pane-base-index 1 works too.
first=$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -x 200 -y 50 "$run 01")
right=$(tmux split-window -P -F '#{pane_id}' -t "$first" -h "$run 02")
tmux split-window -t "$right" -v "$run 03"
tmux split-window -t "$first" -v -l 10 "echo 'VERDICTS'; tail -n 20 -f '$log'"
tmux select-pane -t "$first"
exec tmux attach -t "$session"
