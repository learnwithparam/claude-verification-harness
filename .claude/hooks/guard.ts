// PreToolUse: Claude may not read the holdout tests, nor change the tests, the harness or these hooks.
// A permission rule only covers the tool it names (Read), so this also catches cat, grep and git in Bash.
const { tool_name: tool, tool_input: input = {} } = await Bun.stdin.json();

function deny(reason: string): never {
  console.log(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: reason },
  }));
  process.exit(0);
}

const GIT_ALLOWED = new Set(["status", "diff", "log", "add", "commit", "branch"]);
const PROTECTED = /(^|\/)(tests|harness|\.claude)\//;
const text = JSON.stringify(input);

if (/holdout/i.test(text)) {
  deny("The holdout tests belong to the reviewer: your work is graded on them, never shown them. Work from the ticket.");
}
if (["Edit", "Write", "MultiEdit", "NotebookEdit"].includes(tool) && PROTECTED.test(String(input.file_path ?? input.notebook_path ?? ""))) {
  deny("Only src/ is yours to change. The tests, the harness and the hooks are how your work is checked.");
}
if (tool === "Bash") {
  const cmd = String(input.command ?? "");
  if (/(^|[^\w-])(harness|\.claude)\b/.test(cmd) || /(^|[;&|(]\s*)make\b/.test(cmd)) {
    deny("The harness runs when you stop, not before. Use `bun test tests` for the visible tests.");
  }
  // git is an allowlist: show, grep, cat-file and friends read any file in any commit, the holdout included.
  const gitCalls = [...cmd.matchAll(/\bgit\b\s*(\S*)/g)].map((m) => m[1]);
  const showsPatches = gitCalls.length > 0 && /\s(-p|--patch)\b/.test(cmd);
  if (gitCalls.some((sub) => !GIT_ALLOWED.has(sub)) || showsPatches) {
    deny("That git command can reach files outside your working tree. Use git status and git diff.");
  }
  if (/(^|\s)tests\//.test(cmd) && /(>|\bsed\s+-i|\bperl\s+-i|\brm\b|\bmv\b|\bcp\b|\btee\b)/.test(cmd)) {
    deny("Only src/ is yours to change. The tests are how your work is checked.");
  }
}
