#!/usr/bin/env bash
# Stop hook. Inside a factory stage, checks the stage's JSON file against the
# schema the runner wrote to $FACTORY_SCRATCH_DIR/artifact.schema.json, and
# sends the agent back to fix it at most twice. Any error lets the stop through:
# the runner validates the file again and rejects it as before.
set -uo pipefail

[ -n "${FACTORY_STAGE:-}" ] && [ -n "${FACTORY_SCRATCH_DIR:-}" ] && [ -n "${FACTORY_ARTIFACT_DIR:-}" ] || exit 0
[ -f "$FACTORY_SCRATCH_DIR/artifact.schema.json" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

SCRIPT="$(mktemp)" || exit 0
trap 'rm -f "$SCRIPT"' EXIT

cat >"$SCRIPT" <<'PY'
import json
import os
import sys

MAX_BLOCKS = 2
# What JS String.trim() removes; Python's bare strip() also removes \x1c-\x1f and \x85.
JS_SPACE = " \t\n\v\f\r\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff"


def fits(prop, v):
    # Mirrors fits() in src/schemas.ts; tests/stop-artifact.test.ts holds them to the same answers.
    if isinstance(prop.get("anyOf"), list):
        return any(fits(p, v) for p in prop["anyOf"])
    if isinstance(prop.get("enum"), list):
        return any(v == e and type(v) is type(e) for e in prop["enum"])
    t = prop.get("type")
    if t == "string":
        return isinstance(v, str)
    if t == "integer":
        return isinstance(v, int) and not isinstance(v, bool) or isinstance(v, float) and v.is_integer()
    if t == "boolean":
        return isinstance(v, bool)
    if t == "number":
        return isinstance(v, (int, float)) and not isinstance(v, bool) and prop.get("minimum", float("-inf")) <= v <= prop.get("maximum", float("inf"))
    if t == "array":
        return isinstance(v, list) and all(fits(prop.get("items", {}), x) for x in v)
    if t == "object":
        return isinstance(v, dict)
    return True


def problem(name, schema, path, stopped_owes_only_outcome=False):
    # Mirrors validateStepJson's checks in src/artifacts.ts: object, unknown field,
    # outcome and summary, required fields (skipped for blocked or failed), types.
    if not os.path.isfile(path):
        return f"{name} was not written"
    try:
        with open(path, encoding="utf-8") as f:
            o = json.load(f, parse_constant=lambda c: 1 / 0)  # JSON.parse rejects NaN and Infinity
    except Exception:
        return f"{name} is not valid JSON"
    if not isinstance(o, dict):
        return f"{name} is not a JSON object"
    props = schema["properties"]
    extra = next((k for k in o if k not in props), None)
    if extra is not None:
        return f'{name} has unknown field "{extra}"'
    if "outcome" in o and o["outcome"] not in ("complete", "blocked", "failed"):
        return f"{name}: step outcome must be complete, blocked, or failed"
    if "summary" in o and not (isinstance(o["summary"], str) and o["summary"].strip(JS_SPACE)):
        return f"{name}: step summary must be a non-empty string"
    if o.get("outcome") in ("blocked", "failed") and stopped_owes_only_outcome:
        return None  # validateVerdict checks nothing else on a blocked or failed verify
    if o.get("outcome") not in ("blocked", "failed"):
        missing = next((k for k in schema["required"] if k not in o), None)
        if missing is not None:
            return f'{name}: "{missing}" is required'
    for k, prop in props.items():
        if k in o and not fits(prop, o[k]):
            return f'{name}: "{k}" has the wrong type or value'
    return None


scratch, artifacts = os.environ["FACTORY_SCRATCH_DIR"], os.environ["FACTORY_ARTIFACT_DIR"]
with open(os.path.join(scratch, "artifact.schema.json")) as f:
    spec = json.load(f)
found = problem(spec["file"], spec["schema"], os.path.join(artifacts, spec["file"]), spec.get("stoppedOwesOnlyOutcome") is True)
if found is None:
    sys.exit(0)
counter = os.path.join(scratch, "stop-artifact.count")
blocks = int(open(counter).read() or 0) if os.path.isfile(counter) else 0
if blocks >= MAX_BLOCKS:
    sys.exit(0)
with open(counter, "w") as f:
    f.write(str(blocks + 1))
reason = f"The stage is not done: {found}. Fix {os.path.join(artifacts, spec['file'])} with the Write tool so it matches the schema in the stage instructions, then stop."
print(json.dumps({"decision": "block", "reason": reason}))
PY

out="$(python3 "$SCRIPT" 2>/dev/null)" && printf '%s\n' "$out"
exit 0
