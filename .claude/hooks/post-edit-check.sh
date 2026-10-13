#!/usr/bin/env bash
# PostToolUse hook, opt-in. In the build stage, runs .factory/config.json's
# postEditCommand (an argv list; {file} becomes the edited path, no shell) after
# each edit, and hands a failure's output back to the agent. Unset or [] is off.
set -uo pipefail

[ "${FACTORY_STAGE:-}" = "build" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

out="$(python3 -c '
import json, os, signal, subprocess, sys
event = json.load(sys.stdin)
path = (event.get("tool_input") or {}).get("file_path")
cwd = event.get("cwd") or os.getcwd()
if not isinstance(path, str) or not path:
    sys.exit(0)
# The factory'"'"'s own files (artifacts, comments, scratch) are not code to check.
real = os.path.realpath(os.path.join(cwd, path))
own = [os.path.join(cwd, ".factory"), os.environ.get("FACTORY_ARTIFACT_DIR"), os.environ.get("FACTORY_SCRATCH_DIR")]
if any(d and (real + os.sep).startswith(os.path.realpath(d) + os.sep) for d in own):
    sys.exit(0)
try:
    with open(os.path.join(cwd, ".factory", "config.json")) as f:
        argv = json.load(f).get("postEditCommand") or []
except (OSError, ValueError):
    sys.exit(0)
if not isinstance(argv, list) or not argv or not all(isinstance(a, str) for a in argv):
    sys.exit(0)
argv = [a.replace("{file}", path) for a in argv]
try:
    # Its own process group, so a timeout also kills grandchildren holding the pipe.
    run = subprocess.Popen(argv, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
except OSError as e:
    output, code = str(e), "not run"
else:
    try:
        output = run.communicate(timeout=60)[0].strip()
        code = run.returncode
    except subprocess.TimeoutExpired:
        os.killpg(run.pid, signal.SIGKILL)
        run.communicate()
        output, code = "timed out after 60s", "timeout"
    if code == 0:
        sys.exit(0)
print(json.dumps({"decision": "block", "reason": f"postEditCommand ({argv[0]}) failed on {path} (exit {code}). Fix it before moving on:\n{output[-2000:]}"}))
' 2>/dev/null)" && printf '%s\n' "$out"
exit 0
