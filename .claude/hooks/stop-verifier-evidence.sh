#!/usr/bin/env bash
# Stop hook. In the verify stage, when the session's last message says a command was
# refused or a criterion could not be verified, sends it back once to re-run the
# command in an allowed form. Any error lets the stop through.
set -uo pipefail

[ "${FACTORY_STAGE:-}" = "verify" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

out="$(python3 -c '
import json, re, sys
event = json.load(sys.stdin)
# A repo updated from v2 may still register this on SubagentStop; only the session counts.
if event.get("hook_event_name") != "Stop" or event.get("stop_hook_active"):
    sys.exit(0)
text = event.get("last_assistant_message") or ""
# A refusal names the command or tool refused, so "GET /admin is denied with 403" and a
# file write failing with "Permission denied" are results. The gap may cross dotted paths.
if re.search(r"\b(command|bash|shell|tool)\b[^\n]{0,80}\b(denied|refused)\b|could ?n.?o?t (be )?verif|unable to verif", text, re.I):
    print(json.dumps({"decision": "block", "reason": (
        "A command was refused, not Bash itself. Re-run it as one simple command per call, "
        "following the shell rules in your instructions, then report each criterion with the "
        "command you ran and its exit code.")}))
' 2>/dev/null)" && printf '%s\n' "$out"
exit 0
