#!/usr/bin/env bash
# The one verdict: static gates, then the holdout tests. The last line is always
# VERIFY: GREEN or VERIFY: RED, and the verdict is appended to the shared log.
set -u
cd "$(dirname "$0")/.."
source harness/lib.sh

gates=$(bash harness/gates.sh); gates_ok=$?
holdout=$(bash harness/holdout.sh 2>&1); holdout_ok=$?
report=$(printf "%s\n%s" "$gates" "$holdout" | sed '/^$/d')
t=$(ticket); label="${t:+ticket $t}"; label="${label:-main}"

if [ $gates_ok -eq 0 ] && [ $holdout_ok -eq 0 ]; then
  echo "$(date +%H:%M:%S) GREEN  $label" >> "$(verdict_log)"
  echo "VERIFY: GREEN"
  exit 0
fi
echo "$report"
first=$(echo "$report" | grep -m1 -E "FAILED" | sed -E 's/^[A-Z ]+FAILED: //'); first="${first:-$(echo "$report" | head -n 1)}"
echo "$(date +%H:%M:%S) RED    $label  $first" >> "$(verdict_log)"
echo "VERIFY: RED"
exit 1
