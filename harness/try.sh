#!/usr/bin/env bash
# Gives one ticket its own worktree on branch ticket-NN, without the holdout folder in it,
# then opens Claude there on that ticket.
set -eu
cd "$(dirname "$0")/.."
n=$(printf "%02d" "$((10#${1:?usage: try.sh <ticket number>}))")
wt=".worktrees/ticket-$n"
if [ ! -d "$wt" ]; then
  git worktree add -q -b "ticket-$n" "$wt" main 2>/dev/null || git worktree add -q "$wt" "ticket-$n"
  # The holdout tests stay in the commit but never land on disk where Claude works.
  git -C "$wt" sparse-checkout set --no-cone '/*' '!/holdout/' >/dev/null
fi
[ "${NO_CLAUDE:-}" = 1 ] && { echo "$wt"; exit 0; }
cd "$wt"
exec claude --model "${MODEL:-sonnet}" --permission-mode acceptEdits "/ticket $n"
