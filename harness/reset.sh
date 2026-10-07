#!/usr/bin/env bash
# Removes every ticket worktree, branch and verdict, back to a fresh clone.
set -u
cd "$(dirname "$0")/.."
tmux kill-session -t harness 2>/dev/null || true
for wt in .worktrees/ticket-*; do [ -d "$wt" ] && git worktree remove --force "$wt"; done
git worktree prune
git branch --list 'ticket-*' --format='%(refname:short)' | xargs -r git branch -D >/dev/null
rm -rf .claude/state "$(git rev-parse --path-format=absolute --git-common-dir)/harness-verdicts.log"
echo "Reset: no ticket worktrees, no verdicts."
