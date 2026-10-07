#!/usr/bin/env bash
# Called by the /ticket skill: records which ticket is in progress, resets the reject count,
# and prints the ticket for Claude to read.
set -u
cd "$(dirname "$0")/.."
source harness/lib.sh
n=$(printf "%02d" "$((10#${1:?usage: start-ticket.sh <number>}))")
file=$(ls tickets/"$n"-*.md 2>/dev/null | head -n 1)
[ -z "$file" ] && { echo "No ticket $n in tickets/."; exit 1; }
mkdir -p "$STATE_DIR"
echo "$n" > "$STATE_DIR/ticket"
echo 0 > "$STATE_DIR/rejects"
cat "$file"
