// Stop: Claude may finish only when the harness says GREEN. The reason for a RED goes back to Claude,
// and after three REDs the work goes to a human. This count is the loop guard; stop_hook_active would
// let Claude stop after a single rejection.
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";

const MAX_REJECTS = 3;
const MAX_FEEDBACK_CHARS = 4000;

await Bun.stdin.text();
const dir = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
const state = (name: string) => `${dir}/.claude/state/${name}`;
const read = (name: string) => (existsSync(state(name)) ? readFileSync(state(name), "utf8").trim() : "");

// On a ticket-NN branch the branch decides, so deleting the state file cannot switch the reviewer off.
const branch = Bun.spawnSync(["git", "branch", "--show-current"], { cwd: dir }).stdout.toString().trim();
const ticket = branch.match(/^ticket-(\d+)$/)?.[1] ?? read("ticket");
if (!ticket) process.exit(0);
mkdirSync(`${dir}/.claude/state`, { recursive: true });

const run = Bun.spawnSync(["bash", "harness/verify.sh"], { cwd: dir });
if (run.exitCode === 0) {
  writeFileSync(state("rejects"), "0");
  process.exit(0);
}

const rejects = Number(read("rejects") || 0) + 1;
writeFileSync(state("rejects"), String(rejects));
const reasons = run.stdout.toString().split("\n").filter((l) => l && !l.startsWith("VERIFY:")).join("\n").slice(0, MAX_FEEDBACK_CHARS);

if (rejects >= MAX_REJECTS) {
  const commonDir = Bun.spawnSync(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd: dir }).stdout.toString().trim();
  const time = new Date().toTimeString().slice(0, 8);
  appendFileSync(`${commonDir}/harness-verdicts.log`, `${time} HUMAN  ticket ${ticket}  rejected ${rejects} times, needs a human\n`);
  console.log(JSON.stringify({ systemMessage: `NEEDS HUMAN: ticket ${ticket} was rejected ${rejects} times.\n${reasons}` }));
  process.exit(0);
}

console.error(`The reviewer rejected this work (attempt ${rejects} of ${MAX_REJECTS}).
${reasons}
Fix src/ until these pass. You cannot read the holdout tests: each name says what the product owner expects.`);
process.exit(2);
