#!/usr/bin/env bash
# Three Claudes on three tickets, and a fourth pane that prints every verdict as it lands.
set -eu
cd "$(dirname "$0")/.."
command -v tmux >/dev/null || { echo "tmux is not installed: run 'make try T=01' in three terminals instead."; exit 1; }
session=harness
tmux kill-session -t "$session" 2>/dev/null || true
log="$(git rev-parse --path-format=absolute --git-common-dir)/harness-verdicts.log"
touch "$log"
tmux new-session -d -s "$session" -n run "bash harness/try.sh 01"
tmux split-window -t "$session" -h "bash harness/try.sh 02"
tmux split-window -t "$session" -v "bash harness/try.sh 03"
tmux select-pane -t "$session:run.0"
tmux split-window -t "$session" -v -l 10 "echo 'VERDICTS'; tail -n 20 -f '$log'"
tmux select-pane -t "$session:run.0"
exec tmux attach -t "$session"
