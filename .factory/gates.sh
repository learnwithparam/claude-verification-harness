#!/usr/bin/env bash
# Runs every gate in .factory/config.json and prints exactly one summary
# line the runner parses: FACTORY_GATES: status=... passed=N failed=N skipped=N failed_gates=a,b
# Exit code: 0 GREEN, 1 RED, 2 MISCONFIGURED.
set -u
cd "$(dirname "$0")/.."

CONFIG=".factory/config.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "FACTORY_GATES: status=MISCONFIGURED passed=0 failed=0 skipped=0 failed_gates=jq-not-found"
  exit 2
fi

if [ ! -f "$CONFIG" ]; then
  echo "FACTORY_GATES: status=MISCONFIGURED passed=0 failed=0 skipped=0 failed_gates=config-missing"
  exit 2
fi

if ! jq empty "$CONFIG" >/dev/null 2>&1; then
  echo "FACTORY_GATES: status=MISCONFIGURED passed=0 failed=0 skipped=0 failed_gates=config-invalid-json"
  exit 2
fi

# Monorepo: each entry in .packages runs its gates from its own directory, only
# when the diff against the base touches a file under its path (or always is
# true). Top-level .gates always run. The base is $FACTORY_GATES_BASE, else
# origin/<config base>; with no base to diff against, or a diff that touches no
# package, every package runs, so a change is never shipped unchecked.
gate_count=$(jq '[(.gates // [])[], ((.packages // [])[] | (.gates // [])[])] | length' "$CONFIG" 2>/dev/null || echo "")
if [ -z "$gate_count" ] || [ "$gate_count" -eq 0 ]; then
  echo "FACTORY_GATES: status=MISCONFIGURED passed=0 failed=0 skipped=0 failed_gates=no-gates-defined"
  exit 2
fi

passed=0
failed=0
skipped=0
required_failed_names=()
optional_failed_names=()

# run_gate <dir> <label> <cmd> <required>
run_gate() {
  local dir=$1 name=$2 cmd=$3 required=$4 gate_log
  echo "--- gate: $name ($cmd) ---"
  gate_log=$(mktemp "${TMPDIR:-/tmp}/factory-gate.XXXXXX")
  if (cd "$dir" && eval "$cmd") > "$gate_log" 2>&1; then
    echo "PASS: $name"
    passed=$((passed + 1))
  else
    echo "FAIL: $name"
    tail -n 20 "$gate_log"
    if [ "$required" = "true" ]; then
      failed=$((failed + 1))
      required_failed_names+=("$name")
    else
      skipped=$((skipped + 1))
      optional_failed_names+=("$name")
    fi
  fi
  rm -f "$gate_log"
}

top_count=$(jq '(.gates // []) | length' "$CONFIG")
for i in $(seq 0 $((top_count - 1))); do
  run_gate . "$(jq -r ".gates[$i].name" "$CONFIG")" "$(jq -r ".gates[$i].cmd" "$CONFIG")" "$(jq -r ".gates[$i].required" "$CONFIG")"
done

package_count=$(jq '(.packages // []) | length' "$CONFIG")
if [ "$package_count" -gt 0 ]; then
  base=${FACTORY_GATES_BASE:-origin/$(jq -r '.base // "main"' "$CONFIG")}
  changed=""
  if git rev-parse --verify -q "$base" >/dev/null 2>&1; then
    changed=$( { git diff --name-only "$base"...HEAD; git diff --name-only HEAD; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u)
  else
    echo "--- no base $base to diff against: every package runs ---"
  fi
  selected=()
  touched=0
  for i in $(seq 0 $((package_count - 1))); do
    path=$(jq -r ".packages[$i].path" "$CONFIG")
    path=${path%/}
    if [ -z "$changed" ] || printf '%s\n' "$changed" | grep -q "^$path/"; then
      selected+=("$i")
      touched=1
    elif [ "$(jq -r ".packages[$i].always // false" "$CONFIG")" = "true" ]; then
      selected+=("$i")
    fi
  done
  if [ -n "$changed" ] && [ "$touched" -eq 0 ]; then
    echo "--- the diff touches no package: every package runs ---"
    selected=($(seq 0 $((package_count - 1))))
  fi
  for i in $(seq 0 $((package_count - 1))); do
    path=$(jq -r ".packages[$i].path" "$CONFIG")
    path=${path%/}
    case " ${selected[*]:-} " in
      *" $i "*) ;;
      *) echo "--- package $path: untouched, its gates do not run ---"; continue ;;
    esac
    n=$(jq ".packages[$i].gates | length" "$CONFIG")
    for j in $(seq 0 $((n - 1))); do
      run_gate "$path" "$path:$(jq -r ".packages[$i].gates[$j].name" "$CONFIG")" "$(jq -r ".packages[$i].gates[$j].cmd" "$CONFIG")" "$(jq -r ".packages[$i].gates[$j].required" "$CONFIG")"
    done
  done
fi

all_failed_names=()
for n in "${required_failed_names[@]:-}" "${optional_failed_names[@]:-}"; do
  [ -n "$n" ] && all_failed_names+=("$n")
done
failed_gates=$(IFS=,; echo "${all_failed_names[*]:-}")

if [ "$failed" -gt 0 ]; then
  status="RED"
  exit_code=1
else
  status="GREEN"
  exit_code=0
fi

echo "FACTORY_GATES: status=$status passed=$passed failed=$failed skipped=$skipped failed_gates=$failed_gates"
exit $exit_code
