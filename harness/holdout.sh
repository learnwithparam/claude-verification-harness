#!/usr/bin/env bash
# Runs the ticket's holdout tests from the commit the work started on, outside the working tree.
# Prints only each failing test's name and its expected and received values, never the test source.
set -u
cd "$(dirname "$0")/.."
source harness/lib.sh
t=$(ticket)
[ -z "$t" ] && exit 0

base=$(base_commit)
file=$(git ls-tree --name-only "$base" holdout/ | grep "^holdout/$t-" | head -n 1)
[ -z "$file" ] && { echo "no holdout tests for ticket $t"; exit 1; }

run=$(mktemp -d "${TMPDIR:-/tmp}/holdout.XXXXXX")
trap 'rm -rf "$run"' EXIT
mkdir -p "$run/holdout"
git show "$base:$file" > "$run/$file"
ln -s "$PWD/src" "$run/src"

out=$(cd "$run" && bun test "./$file" 2>&1)
status=$?
[ $status -eq 0 ] && exit 0

echo "$out" | awk '
  /^Expected:/ { want = $0; sub(/^Expected: */, "", want) }
  /^Received:/ { got = $0; sub(/^Received: */, "", got) }
  /^(error: |[A-Za-z]*Error: )/ && !/expect\(/ { err = $0 }
  /^\(fail\) / {
    name = $0; sub(/^\(fail\) /, "", name); sub(/ \[[0-9.]+m?s\]$/, "", name)
    if (want != "") printf "HOLDOUT FAILED: %s (expected %s, received %s)\n", name, want, got
    else if (err != "") printf "HOLDOUT FAILED: %s (%s)\n", name, err
    else printf "HOLDOUT FAILED: %s\n", name
    want = ""; got = ""; err = ""
  }'
exit 1
