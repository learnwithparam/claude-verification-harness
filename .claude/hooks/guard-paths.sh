#!/usr/bin/env bash
# PreToolUse guard for Edit|Write|MultiEdit|NotebookEdit|Bash|Agent. Refuses writes to
# protected paths (.factory/config.json's protectedPaths, plus .claude/** and
# .factory/** always), merges and force-pushes, and inside a factory stage the
# shell shapes the stage's permission mode refuses, naming the fix, and a
# backgrounded subagent. Writes to
# `.factory/runs/**` always pass: that is where a stage hands back its output.
# Exit 2 + stderr blocks.
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# The script is written to a temp file rather than piped via `python3 -
# <<PY`: that form redirects the python3 process's OWN stdin to the heredoc
# text, leaving nothing on stdin for json.load() to read the hook's JSON
# from. A temp file keeps stdin free. (Also: macOS ships bash 3.2, which
# mis-parses a heredoc containing parentheses nested inside `<(...)`.)
SCRIPT="$(mktemp)"
trap 'rm -f "$SCRIPT"' EXIT

cat >"$SCRIPT" <<'PY'
import fnmatch
import json
import os
import re
import subprocess
import sys

project_dir = sys.argv[1]
try:
    hook_input = json.load(sys.stdin)
except Exception:
    print("guard-paths: blocked, could not parse the hook input, so paths can't be checked (fails closed)", file=sys.stderr)
    sys.exit(2)

if not isinstance(hook_input, dict) or not isinstance(hook_input.get("tool_input", {}), dict):
    print("guard-paths: blocked, the hook input is not a tool call object (fails closed)", file=sys.stderr)
    sys.exit(2)
tool_name = hook_input.get("tool_name", "")
tool_input = hook_input.get("tool_input", {})


def block(reason):
    print(reason, file=sys.stderr)
    sys.exit(2)


# The shapes `--permission-mode dontAsk` refuses even when every command in
# them is allowed (measured on claude 2.1.289). Its own refusal says only
# "Bash denied", which verifiers read as "no shell at all" and gave up.
WORD_START = " \t\n;&|()"


def live_only(text):
    # What bash still expands inside double quotes and unquoted heredoc bodies.
    out = ["x"] * len(text)
    for m in re.finditer(r"\$\(|\$\?|`", text):
        out[m.start() : m.end()] = m.group(0)
    return "".join(out)


HEREDOC = re.compile(r"<<-?[ \t]*(\\?)(['\"]?)([A-Za-z0-9_.-]+)\2")


def unquoted(command):
    # Masks quoted text, comments and heredoc bodies with x, so "a{1,3}", "x && cd"
    # or an apostrophe in a commit message is inert, while $( $? and ` stay live.
    out, quote, i, n, heredocs = [], None, 0, len(command), []
    while i < n:
        c = command[i]
        if quote is None:
            heredoc = HEREDOC.match(command, i)
            if command[i : i + 3] == "<<<":
                out.append("<<<")
                i += 3
            elif c == "\\":
                out.append("xx"[: n - i])
                i += 2
            elif c == "#" and (i == 0 or command[i - 1] in WORD_START):
                stop = command.find("\n", i)
                stop = n if stop < 0 else stop
                out.append("x" * (stop - i))
                i = stop
            elif heredoc:
                heredocs.append((heredoc.group(3), bool(heredoc.group(1) or heredoc.group(2))))
                out.append("<<" + "x" * (heredoc.end() - i - 2))
                i = heredoc.end()
            elif c == "\n" and heredocs:
                out.append(c)
                i += 1
                for delim, quoted in heredocs:
                    while i < n:
                        stop = command.find("\n", i)
                        stop = n if stop < 0 else stop
                        line = command[i:stop]
                        out.append(line if line.lstrip("\t") == delim else "x" * len(line) if quoted else live_only(line))
                        out.append("\n" if stop < n else "")
                        i = stop + 1
                        if line.lstrip("\t") == delim:
                            break
                heredocs = []
            else:
                if command[i : i + 2] == "$'":
                    quote, c = "$'", "$'"
                    i += 1
                elif c in "'\"":
                    quote = c
                out.append(c)
                i += 1
            continue
        if c == "\\" and quote != "'":
            out.append("xx"[: n - i])
            i += 2
            continue
        if c == quote or quote == "$'" and c == "'":
            quote = None
            out.append(c)
        elif quote == '"':
            kept = live_only(command[i : i + 2])
            if kept in ("$(", "$?"):
                out.append(kept)
                i += 2
                continue
            out.append(kept[0])
        else:
            out.append("x")
        i += 1
    return "".join(out)


SEPARATORS = r"&&|\|\||;|\||\n|(?<![>&])&(?![>&])"
# Words after which the next word is still the command bash runs.
PREFIX_WORDS = {"!", "if", "then", "else", "elif", "do", "while", "until", "time", "command", "builtin", "exec", "nohup", "env"}


def shell_shape_problems(command):
    text = unquoted(command)
    problems = []
    for match in re.finditer(r"(&>>?|(?:(?<!\d)|(?<=&\d))\d*(?:>&|>>?|>\|))\s*([^\s;&|<>()]*)", text):
        op, target = match.groups()
        # A bare number or - is a descriptor only after >& (2>&1); after > it is a file name.
        descriptor = op.endswith(">&") and re.fullmatch(r"\d+|-", target)
        if target not in ("/dev/null", "/dev/stdout", "/dev/stderr") and not descriptor:
            problems.append("> or >> to a file (a stage cannot write files from the shell: to revert a file use git restore --source=<ref> -- <file>; to see output just run the command; to write a run file use the Write tool)")
            break
    if "$(" in text or "`" in text:
        problems.append("$(...) or backticks (run the inner command on its own first, then use its output)")
    if re.search(r"\$\{?\?", text):
        problems.append("$? (the tool result already shows the exit code; drop the echo)")
    if any("," in m.group(0) or ".." in m.group(0) for m in re.finditer(r"(?<!\$)\{[^{}\s]*\}", text)):
        problems.append("brace expansion (list each path in full)")
    for segment in re.split(SEPARATORS, text):
        words = segment.replace("(", " ").replace("{", " ", 1).split()
        first = 0
        while first < len(words) and (words[first] in PREFIX_WORDS or words[first].startswith("-") and first + 1 < len(words)):
            first += 1
        if first == len(words):
            continue
        if words[first] == "cd":
            problems.append("cd (commands already run in the repo root; give paths from there, or git -C <dir> for git)")
        elif re.match(r"[A-Za-z_][A-Za-z0-9_]*\+?=", words[first]):
            problems.append("a VAR=value prefix (run the command without it)")
    return list(dict.fromkeys(problems))


GIT_VALUE_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env", "--super-prefix", "--attr-source"}
GH_VALUE_OPTS = {"-R", "--repo", "--hostname"}


def merges_or_force_pushes(command):
    # Reads text with quotes, backslashes and continuations removed, from every git or gh
    # word to the next, so quoting, wrappers, `sh -c`, heredoc bodies and $(...) are all
    # caught; quoted text that names a merge is refused too. Linear in the command length.
    for joined in (command, command.replace("\\\n", "")):
        text = re.sub(r"[\\'\"]", "", joined)
        text = re.sub(r"(?<!\d)\d*(?:<<<|<<-?|<>|>>|>\||&>>?|[<>]&?)\s*[^\s;&|<>()]*", " ", text)  # drop redirects
        for segment in re.split(r"[\n;&|()`]", text):
            words = segment.split()
            # A git or gh word starts a command unless it is the value of the previous start's
            # own global option (git -C git ...); after a positional word, -c is sh's, not git's.
            starts, in_globals = [], False
            for k, w in enumerate(words):
                value = in_globals and words[k - 1] in GIT_VALUE_OPTS | GH_VALUE_OPTS
                if os.path.basename(w) in ("git", "gh") and not w.startswith("-") and not value:
                    starts.append(k)
                    in_globals = True
                elif not w.startswith("-") and not value:
                    in_globals = False
            for k, end in zip(starts, starts[1:] + [len(words)]):
                name, rest = os.path.basename(words[k]), words[k + 1 : end]
                value_opts = GIT_VALUE_OPTS if name == "git" else GH_VALUE_OPTS
                positional = [w for j, w in enumerate(rest) if not w.startswith("-") and not (j and rest[j - 1] in value_opts)]
                if name == "gh" and positional[:2] == ["pr", "merge"]:
                    return True
                if name == "git" and positional[:1] == ["merge"]:
                    return True
                if name == "git" and positional[:1] == ["push"] and any(
                    w.startswith("--force") or w == "--mirror" or re.fullmatch(r"-[A-Za-z]*f[A-Za-z]*", w) or w.startswith("+") for w in rest
                ):
                    return True
    return False

if tool_name == "Bash":
    command = tool_input.get("command", "")
    if not isinstance(command, str):
        block("guard-paths: blocked, the Bash command is not a string (fails closed)")
    if merges_or_force_pushes(command):
        block(f"guard-paths: blocked — a stage never merges or force-pushes: {command}")
    if os.environ.get("FACTORY_STAGE"):
        problems = shell_shape_problems(command)
        if problems:
            block("guard-paths: this one command was refused; Bash still works. Rewrite it and carry on. "
                  f"It uses: {'; '.join(problems)}. Command: {command}")
    sys.exit(0)

# A stage that backgrounds a subagent ends its turn before the answer arrives: verify on
# #95 wrote an uncertain verdict, then spent four Opus edits turning it into a pass.
if tool_name == "Agent":
    if os.environ.get("FACTORY_STAGE") and tool_input.get("run_in_background"):
        block("guard-paths: blocked, run this subagent in the foreground (run_in_background: false) "
              "and wait for its answer: a stage must not end its turn before the result is in.")
    sys.exit(0)

if tool_name not in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
    sys.exit(0)

path = tool_input.get("file_path") or tool_input.get("notebook_path") or tool_input.get("path") or ""
if not isinstance(path, str) or not isinstance(hook_input.get("cwd") or "", str):
    block("guard-paths: blocked, the file path or cwd is not a string (fails closed)")
if not path:
    sys.exit(0)

# Protected paths are relative to the worktree holding the file. Roots come from
# git's own worktree list, never from a .git marker the agent could create.
try:
    if not os.path.isabs(path):
        path = os.path.join(hook_input.get("cwd") or project_dir, path)
    path = os.path.realpath(path)
    path.encode("utf-8")
except (ValueError, UnicodeError):
    block("guard-paths: blocked, the file path or cwd cannot be resolved (fails closed)")
roots = [os.path.realpath(project_dir)]
try:
    listing = subprocess.run(["git", "-C", project_dir, "worktree", "list", "--porcelain"], capture_output=True, text=True, timeout=5).stdout
    roots += [os.path.realpath(line[len("worktree "):]) for line in listing.splitlines() if line.startswith("worktree ")]
except Exception:
    pass
inside = [r for r in roots if path.startswith(r + "/")]
root = max(inside, key=len) if inside else roots[0]

rel = path[len(root) + 1 :] if path.startswith(root + "/") else path

if rel.startswith(".factory/runs/"):
    sys.exit(0)

globs = []
config_path = f"{root}/.factory/config.json"
if os.path.lexists(config_path):
    try:
        with open(config_path) as f:
            globs = json.load(f).get("protectedPaths", [])
    except Exception:
        block("guard-paths: blocked, .factory/config.json cannot be read or parsed (fails closed)")
    if not isinstance(globs, list) or not all(isinstance(g, str) for g in globs):
        block("guard-paths: blocked, .factory/config.json protectedPaths is not a list of strings (fails closed)")

globs += [".claude/**", ".factory/**"]

for g in globs:
    if fnmatch.fnmatch(rel, g) or fnmatch.fnmatch(path, g):
        block(f'guard-paths: "{rel}" matches protected path "{g}" — this needs a human, not a stage edit')

sys.exit(0)
PY

# Fail CLOSED, not open: without python3 there is no way to evaluate
# protectedPaths or the merge/force-push blocklist, so every tool call must
# be refused rather than silently let through (audit finding #13 — a bare
# `python3 "$SCRIPT"` on a PATH without python3 exits 127, which Claude Code
# treats as "hook errored", not "hook blocked", so the tool call would have
# gone through anyway).
if ! command -v python3 >/dev/null 2>&1; then
  echo "guard-paths: blocked — python3 is not on PATH, so protected paths can't be checked; refusing every tool call until this is fixed (fails closed, not open)" >&2
  exit 2
fi

python3 "$SCRIPT" "$PROJECT_DIR"
