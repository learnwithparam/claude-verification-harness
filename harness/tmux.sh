#!/usr/bin/env bash
# Three Claudes on three tickets, and a fourth pane that prints every verdict as it lands.
set -eu
cd "$(dirname "$0")/.."
command -v tmux >/dev/null || { echo "tmux is not installed: run 'make try T=01' in three terminals instead."; exit 1; }
session=harness
tmux kill-session -t "$session" 2>/dev/null || true
log="$(git rev-parse --path-format=absolute --git-common-dir)/harness-verdicts.log"
touch "$log"
# A running tmux server keeps its own environment, so the settings travel with each command.
run="env MODEL='${MODEL:-sonnet}' CLAUDE_FLAGS='${CLAUDE_FLAGS:-}' bash harness/try.sh"
tmux new-session -d -s "$session" -n run "$run 01"
tmux split-window -t "$session" -h "$run 02"
tmux split-window -t "$session" -v "$run 03"
tmux select-pane -t "$session:run.0"
tmux split-window -t "$session" -v -l 10 "echo 'VERDICTS'; tail -n 20 -f '$log'"
tmux select-pane -t "$session:run.0"
exec tmux attach -t "$session"
