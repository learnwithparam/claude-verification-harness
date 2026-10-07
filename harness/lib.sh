# Shared by the harness scripts. The ticket in progress is written by start-ticket.sh; on a ticket-NN
# branch the branch name decides, so deleting the state file cannot switch the reviewer off.
STATE_DIR=".claude/state"
ticket() {
  local b; b=$(git branch --show-current 2>/dev/null)
  if [[ "$b" =~ ^ticket-([0-9]+)$ ]]; then echo "${BASH_REMATCH[1]}"; else cat "$STATE_DIR/ticket" 2>/dev/null || true; fi
}
# The commit this work started from, so harness edits made on main later do not count as tampering.
base_commit() { git merge-base HEAD main 2>/dev/null || git rev-parse HEAD; }
# One log for every worktree, so a single pane can watch all the runs.
verdict_log() { echo "$(git rev-parse --path-format=absolute --git-common-dir)/harness-verdicts.log"; }
