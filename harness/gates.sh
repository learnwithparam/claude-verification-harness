#!/usr/bin/env bash
# Static gates: each is one line, a name and a command that must succeed.
# Prints only the gates that fail. Exit 0 when all pass.
set -u
cd "$(dirname "$0")/.."
source harness/lib.sh

failed=0
gate() {
  local name="$1" cmd="$2" out
  if ! out=$(bash -c "$cmd" 2>&1); then
    echo "GATE FAILED: $name"
    [ -n "$out" ] && echo "$out" | head -n 8
    failed=1
  fi
}

gate "cents stay whole numbers"                                '! grep -nE "toFixed|parseFloat" src/*.ts'
gate "no focused or skipped tests"                              '! grep -nE "\.(only|skip)\(" tests/*.ts'
gate "visible tests pass"                                       'out=$(bun test tests 2>&1) || { echo "$out" | grep -E "^\(fail\)"; exit 1; }'
if [ -n "$(ticket)" ]; then
  gate "tests, holdout and harness unchanged by this ticket"    "git diff --stat $(base_commit) -- tests holdout harness .claude/hooks .claude/settings.json .claude/skills .claude/rules .claude/agents | grep . && exit 1 || exit 0"
fi

exit $failed
