#!/usr/bin/env bash
# Runs one mutation against a throwaway copy of HEAD's tree, never the worktree, so the verify
# stage can check a plan criterion like "removing the guard makes the tests fail" without
# editing the tree it judges.
#
#   .factory/mutate.sh [--proof .factory/runs/issue-N/proof.json] <file> <search> <replace> <test-file>...
#
# A mutation runs the repo's own code, so only the verify stage may run it, and only on the
# files and tests the plan's criteria name. What it runs is fixed here, not by the caller:
# - <file> is a tracked, non-symlink source file in HEAD: not a test, not under .factory/,
#   .claude/, .agents/ or .github/, not a protectedPaths match, not a build or config file.
# - <search> occurs exactly once in <file> and is replaced literally. <replace> is one of a fixed
#   set of operators, so a mutation removes or flips behaviour and never adds code: empty (delete
#   the search text), true, false, null, undefined, 0, "", return;, return true;, return false;,
#   return null;, return [];, return {};, or the search text with one ! removed or added, or one
#   comparison swapped (=== and !==, < and >=, > and <=).
# - The runner is the test gate's fileCmd from .factory/config.json, else its cmd, split into words
#   and run as an argv array with the named test files appended. Set fileCmd when cmd ignores file
#   arguments (make check runs the whole suite). Each test file exists in HEAD and has a test path.
# - The copy is a detached git worktree of HEAD, removed afterwards, so a test that reads history
#   or finds a sibling checkout through the common git dir passes there as in the worktree.
# - Dependency directories (node_modules, .venv, venv, vendor) are copied (cloned where the
#   filesystem can), never linked, so a test that writes into them cannot reach the worktree.
# - The tests run with only PATH, HOME (the copy) and TMPDIR (outside the copy, so a test's temp
#   sandbox is never inside the repo it tests) in their environment: no token or other variable of
#   the stage reaches the repo's code.
# The tests run on the unmutated copy first and must pass, then on the mutated copy. Last line:
#   MUTATION: file=<file> status=bites|survives|error failed=<n> reason=<why, on error>
# It fails closed: a runner that cannot start (exit 126 or 127) or is killed, a timeout, a
# no-op replacement, a non-zero exit with no failed test (a crash or compile error),
# or any unexpected failure is status=error, never bites.
# Exit code: 0 bites, 1 survives, 2 error. --proof appends the result to that file's "mutations".
set -u
cd "$(dirname "$0")/.." || exit 2

if ! command -v python3 >/dev/null 2>&1; then
  echo "MUTATION: file=${1:-} status=error failed=0 reason=python3-not-found"
  exit 2
fi

read -r -d '' PY <<'PY'
import json, os, re, shlex, shutil, subprocess, sys, tempfile
from fnmatch import fnmatch

USAGE = "usage: .factory/mutate.sh [--proof .factory/runs/issue-N/proof.json] <file> <search> <replace> <test-file>..."
# The test-path conventions src/proof.ts's TEST_PATH uses (tests/mutate.test.ts keeps them equal).
TEST_PATH = [r"(^|/)(tests?|__tests__|spec)/", r"\.(test|spec)\.[cm]?[jt]sx?$", r"(^|/)test_[^/]*\.py$", r"_test\.(py|go)$", r"_spec\.rb$"]
OFF_LIMITS = [".factory/*", ".claude/*", ".agents/*", ".github/*"]
BUILD_FILES = ["Makefile", "GNUmakefile", "makefile", "package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lock", "bun.lockb", "Cargo.lock", "poetry.lock", "uv.lock", "Gemfile.lock", "go.sum", "*.config.*"]
DEP_DIRS = {"node_modules", ".venv", "venv", "vendor"}
CONSTANTS = ["", "true", "false", "null", "undefined", "0", '""', "return;", "return true;", "return false;", "return null;", "return [];", "return {};"]
SWAPS = [("===", "!=="), ("<", ">="), (">", "<=")]

args = sys.argv[1:]
file = args[2] if args[:1] == ["--proof"] and len(args) > 2 else (args[0] if args else "")


def say(line):
    print(line, flush=True)


def error(reason, why):
    print(f"mutate.sh: {why}", file=sys.stderr, flush=True)
    say(f"MUTATION: file={file} status=error failed=0 reason={reason}")
    sys.exit(2)


# Fails closed: anything unexpected is an error (exit 2), never bites or survives.
def crashed(kind, value, tb):
    print(f"mutate.sh: {kind.__name__}: {value}", file=sys.stderr, flush=True)
    say(f"MUTATION: file={file} status=error failed=0 reason=internal")
    os._exit(2)


sys.excepthook = crashed
TIMEOUT = 900


def is_test(path):
    return any(re.search(p, path) for p in TEST_PATH)


def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True)


proof = ""
if args[:1] == ["--proof"]:
    if len(args) < 2:
        error("usage", USAGE)
    proof, args = args[1], args[2:]
    if not re.fullmatch(r"\.factory/runs/issue-\d+/proof\.json", proof):
        error("bad-proof-path", f"--proof must be .factory/runs/issue-<N>/proof.json, got {proof}")
if len(args) < 4:
    error("usage", USAGE)
file, search, replace, tests = args[0], args[1], args[2], args[3:]
if not search:
    error("usage", "the search text is empty")


def operator(search, replace):
    if replace in CONSTANTS:
        return True
    edits = set()
    for i in range(len(search) + 1):
        edits.add(search[:i] + "!" + search[i:])
        if search[i : i + 1] == "!":
            edits.add(search[:i] + search[i + 1 :])
    for a, b in SWAPS + [(b, a) for a, b in SWAPS]:
        i = search.find(a)
        while i >= 0:
            edits.add(search[:i] + b + search[i + len(a) :])
            i = search.find(a, i + 1)
    return replace in edits


if replace == search:
    error("replace-is-noop", "the replacement equals the search text, so nothing would change")
if not operator(search, replace):
    error("replace-not-allowed", f"the replacement must be a listed constant or the search text with one ! or comparison changed, got {replace!r}")


def check_path(path, what):
    parts = path.split("/")
    if path.startswith("/") or ".." in parts or "" in parts or "." in parts:
        error("bad-path", f"{what} must be a plain path relative to the repo root, got {path}")
    entry = git("ls-tree", "HEAD", "--", path).stdout.split("\t")[0].split()
    if len(entry) < 2 or entry[1] != "blob":
        error("not-in-head", f"{what} {path} is not a file in HEAD")
    if entry[0] == "120000":
        error("bad-path", f"{what} {path} is a symlink")


try:
    with open(".factory/config.json") as f:
        config = json.load(f)
except Exception as e:
    error("config-unreadable", f".factory/config.json cannot be read: {e}")

check_path(file, "the mutated file")
if is_test(file):
    error("target-is-test", f"{file} is a test; mutate the code it tests")
protected = [g for g in config.get("protectedPaths") or [] if isinstance(g, str)]
if any(fnmatch(file, g) for g in OFF_LIMITS + protected) or any(fnmatch(os.path.basename(file), g) for g in BUILD_FILES):
    error("target-off-limits", f"{file} is a factory, protected, build or config file, not source")
for t in tests:
    check_path(t, "the test file")
    if not is_test(t):
        error("not-a-test", f"{t} does not have a test path")

gates = config.get("gates") or []
gate = next((g for g in gates if g.get("role") == "test"), None) or next((g for g in gates if g.get("name") == "test"), None)
gate_cmd = (gate or {}).get("fileCmd") or (gate or {}).get("cmd") or ""
if not gate_cmd or re.search(r"[;&|<>$`()\\\n]", gate_cmd) or re.match(r"\s*[A-Za-z_][A-Za-z0-9_]*=", gate_cmd):
    error("no-test-runner", f"the test gate fileCmd or cmd must be one plain command to run as argv, got {gate_cmd!r}")
argv = shlex.split(gate_cmd) + tests

root = tempfile.mkdtemp(prefix="factory-mutate.")
copy = os.path.join(root, "tree")
git("worktree", "prune")  # forgets a copy a killed run left registered
try:
    if git("worktree", "add", "--detach", "--quiet", copy, "HEAD").returncode != 0:
        error("copy-failed", "could not check HEAD out into a worktree")
    target = os.path.join(copy, file)
    if os.path.islink(target) or not os.path.realpath(target).startswith(os.path.realpath(copy) + os.sep):
        error("bad-path", f"{file} does not resolve inside the copy")
    with open(target, encoding="utf-8", newline="") as f:
        text = f.read()
    count = text.count(search)
    if count == 0:
        error("search-absent", f"the search text does not occur in {file}")
    if count > 1:
        error("search-ambiguous", f"the search text occurs {count} times in {file}; give a longer one that occurs once")

    # Ignored dependency directories, copied (a clone on APFS or btrfs) so the copy runs without a fresh install.
    ignored = git("ls-files", "--others", "--ignored", "--exclude-standard", "--directory").stdout.splitlines()
    for d in (x.rstrip("/") for x in ignored):
        dest = os.path.join(copy, d)
        if os.path.basename(d) not in DEP_DIRS or not os.path.isdir(os.path.dirname(dest)) or os.path.lexists(dest):
            continue
        for cp in (["cp", "-cR"], ["cp", "-R", "--reflink=auto"], ["cp", "-R"]):
            if subprocess.run([*cp, d, dest], capture_output=True).returncode == 0:
                break
            shutil.rmtree(dest, ignore_errors=True)
        else:
            error("copy-failed", f"could not copy {d}")

    tmp = os.path.join(root, "tmp")
    os.makedirs(tmp, exist_ok=True)
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": copy, "TMPDIR": tmp}

    def run():
        try:
            r = subprocess.run(argv, cwd=copy, env=env, capture_output=True, text=True, errors="replace", timeout=TIMEOUT)
        except OSError as e:
            error("no-test-runner", f"could not run {argv[0]}: {e}")
        except subprocess.TimeoutExpired:
            error("timeout", f"the tests ran past {TIMEOUT}s")
        out = r.stdout + r.stderr
        if r.returncode < 0 or r.returncode in (126, 127):
            say("\n".join(out.splitlines()[-30:]))
            error("runner-failed", f"the test runner did not run the tests (exit {r.returncode})")
        return r.returncode, out

    code, out = run()
    if code != 0:
        say("\n".join(out.splitlines()[-30:]))
        error("baseline-red", "the tests fail on the unmutated copy, so a failure after the mutation would prove nothing")
    mutated = text.replace(search, replace, 1)
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(mutated)
    code, out = run()
finally:
    git("worktree", "remove", "--force", copy)
    shutil.rmtree(root, ignore_errors=True)
    git("worktree", "prune")

if code == 0:
    status, failed = "survives", "0"
else:
    plain = re.sub(r"\x1b\[[0-9;]*m", "", out)
    counts = [int(m.group(1)) for m in re.finditer(r"(\d+)\s+(?:fail|failed|failing|failures?)\b", plain, re.I)]
    counts.append(len(re.findall(r"^--- FAIL", plain, re.M)))
    if max(counts) == 0:
        # A non-zero exit with no failed test is a crash or a compile error, which proves nothing.
        say("\n".join(out.splitlines()[-30:]))
        error("no-test-failed", "the tests exited non-zero but reported no failed test (a crash or compile error?)")
    status, failed = "bites", str(max(counts))
say("\n".join(out.splitlines()[-30:]))
if proof:
    try:
        with open(proof) as f:
            record = json.load(f)
    except FileNotFoundError:
        record = {}
    except Exception as e:
        error("record-failed", f"could not read {proof}: {e}")
    entry = {"file": file, "search": search, "replace": replace, "cmd": shlex.join(argv), "status": status, "failed": failed, "exitCode": code, "tail": out[-2000:]}
    record.setdefault("mutations", []).append(entry)
    os.makedirs(os.path.dirname(proof), exist_ok=True)
    with open(proof, "w") as f:
        f.write(json.dumps(record, indent=2) + "\n")
say(f"MUTATION: file={file} status={status} failed={failed}")
sys.exit(0 if status == "bites" else 1)
PY

exec python3 -c "$PY" "$@"
