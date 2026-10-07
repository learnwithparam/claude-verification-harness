// PostToolUse: after an edit to src/, run the static gates and hand any failure back as context.
// Plain stdout from this hook never reaches Claude; additionalContext does.
const { tool_input: input = {} } = await Bun.stdin.json();
if (!/(^|\/)src\//.test(String(input.file_path ?? ""))) process.exit(0);

const dir = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
const run = Bun.spawnSync(["bash", "harness/gates.sh"], { cwd: dir });
if (run.exitCode === 0) process.exit(0);

console.log(JSON.stringify({
  hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: `Gates failing after this edit:\n${run.stdout.toString().slice(0, 2000)}` },
}));
