// The harness's own test: every claim the README and the lesson make about it, run against a fresh clone.
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { copyFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const ROOT = join(import.meta.dir, "..");
let repo = "";

function sh(cmd: string, cwd = repo, stdin = "") {
  const r = Bun.spawnSync(["bash", "-c", cmd], { cwd, stdin: new TextEncoder().encode(stdin), env: { ...process.env, CLAUDE_PROJECT_DIR: cwd } });
  return { code: r.exitCode, out: r.stdout.toString(), err: r.stderr.toString() };
}
const verify = () => sh("bash harness/verify.sh");
const useSolution = (n: string) => copyFileSync(join(ROOT, `harness/fixtures/solution-${n}.ts`), join(repo, "src/cart.ts"));
const restoreSrc = () => sh("git checkout -q -- src");
const startTicket = (n: string) => sh(`bash harness/start-ticket.sh ${n}`);
const guard = (tool: string, input: object) => sh("bun .claude/hooks/guard.ts", repo, JSON.stringify({ tool_name: tool, tool_input: input }));
const denied = (r: { out: string }) => r.out.includes('"permissionDecision":"deny"');

beforeAll(() => {
  const dir = mkdtempSync(join(tmpdir(), "harness-test-"));
  repo = join(dir, "repo");
  // The working tree, not the last commit, so the test checks the harness as it is now.
  sh(`mkdir -p "${repo}" && git ls-files -co --exclude-standard | grep -v '^harness/fixtures/' | tar -cf - -T - | tar -xf - -C "${repo}"`, ROOT);
  sh("git init -q -b main && git add -A && git -c user.name=t -c user.email=t@t commit -qm base");
});
afterAll(() => rmSync(join(repo, ".."), { recursive: true, force: true }));

describe("verify", () => {
  test("main with no ticket is GREEN", () => {
    expect(verify().code).toBe(0);
  });

  test("a float in the code turns a gate RED, with the gate named", () => {
    writeFileSync(join(repo, "src/cart.ts"), readFileSync(join(repo, "src/cart.ts"), "utf8") + "\nexport const price = (c: number) => (c / 100).toFixed(2);\n");
    const r = verify();
    restoreSrc();
    expect(r.code).toBe(1);
    // The exact line the lesson slide shows.
    expect(r.out).toContain("GATE FAILED: cents stay whole numbers\n");
  });

  test("an unfinished ticket is RED and names the failing holdout test", () => {
    startTicket("01");
    const r = verify();
    expect(r.code).toBe(1);
    expect(r.out).toContain("HOLDOUT FAILED: SAVE10 takes 10% off the items");
  });

  test("the holdout report never prints the holdout source", () => {
    startTicket("01");
    const r = verify();
    expect(r.out).not.toContain("expect(");
    expect(r.out).not.toContain("applyCode(items(");
  });

  for (const n of ["01", "02", "03"]) {
    test(`the reference solution for ticket ${n} is GREEN`, () => {
      startTicket(n);
      useSolution(n);
      const r = verify();
      restoreSrc();
      expect(r.out).toContain("VERIFY: GREEN");
    });
  }

  test("editing a visible test on a ticket turns the tamper gate RED", () => {
    startTicket("01");
    useSolution("01");
    writeFileSync(join(repo, "tests/cart.test.ts"), readFileSync(join(repo, "tests/cart.test.ts"), "utf8").replace("4499", "4498").replace("4499", "4498"));
    const r = verify();
    sh("git checkout -q -- tests");
    restoreSrc();
    expect(r.out).toContain("GATE FAILED: tests, holdout and harness unchanged");
  });
});

describe("stop hook", () => {
  const stop = () => sh("bun .claude/hooks/stop.ts", repo, "{}");

  test("RED blocks the stop with the reason, and the third RED hands over to a human", () => {
    startTicket("01");
    const first = stop();
    expect(first.code).toBe(2);
    expect(first.err).toContain("attempt 1 of 3");
    expect(first.err).toContain("HOLDOUT FAILED");
    expect(stop().code).toBe(2);
    const third = stop();
    expect(third.code).toBe(0);
    expect(third.out).toContain("NEEDS HUMAN");
  });

  test("GREEN lets Claude stop and resets the count", () => {
    startTicket("01");
    stop();
    useSolution("01");
    const r = stop();
    restoreSrc();
    expect(r.code).toBe(0);
    expect(readFileSync(join(repo, ".claude/state/rejects"), "utf8").trim()).toBe("0");
  });

  test("on a ticket branch, deleting the state file does not switch the reviewer off", () => {
    sh("git checkout -q -b ticket-01");
    rmSync(join(repo, ".claude/state"), { recursive: true, force: true });
    const r = stop();
    sh("git checkout -q main");
    expect(r.code).toBe(2);
  });

  test("with no ticket in progress it never blocks", () => {
    rmSync(join(repo, ".claude/state/ticket"), { force: true });
    expect(stop().code).toBe(0);
  });
});

describe("guard hook", () => {
  test.each([
    ["Read", { file_path: "holdout/01-discount-code.holdout.test.ts" }],
    ["Grep", { pattern: "SAVE10", path: "holdout" }],
    ["Glob", { pattern: "holdout/**" }],
    ["Bash", { command: "cat holdout/01-discount-code.holdout.test.ts" }],
    ["Bash", { command: "git show main:holdout/01-discount-code.holdout.test.ts" }],
    ["Bash", { command: "git grep SAVE10 main" }],
    ["Bash", { command: "git -C . show main:tests/cart.test.ts" }],
    ["Bash", { command: "git log -p" }],
    ["Bash", { command: "cd .claude && rm state/ticket" }],
    ["Bash", { command: "rm -rf .claude" }],
    ["Bash", { command: "cd harness; echo 'exit 0' > verify.sh" }],
    ["Bash", { command: "bash harness/verify.sh" }],
    ["Bash", { command: "make verify" }],
    ["Bash", { command: "bun test tests && make verify" }],
    ["Bash", { command: "sed -i '' 's/4499/1/' tests/cart.test.ts" }],
    ["Bash", { command: "python3 - <<'EOF'\nopen('tests/cart.test.ts','w').write(t)\nEOF" }],
    ["Bash", { command: "bun -e \"await Bun.write('tests/cart.test.ts', '')\"" }],
    ["Edit", { file_path: `${"/x"}/tests/cart.test.ts` }],
    ["Bash", { command: "python3 - <<'PY'\np='src/cart.ts'\nopen(p,'w').write(s)\nPY" }],
    ["Bash", { command: "sed -i '' 's/toFixed/x/' src/cart.ts" }],
    ["Bash", { command: "cat > src/cart.ts <<'EOF'\nexport {}\nEOF" }],
    ["Write", { file_path: "harness/gates.sh" }],
    ["Edit", { file_path: ".claude/settings.json" }],
  ])("denies %s %j", (tool, input) => {
    expect(denied(guard(tool, input))).toBe(true);
  });

  test.each([
    ["Edit", { file_path: "src/cart.ts" }],
    ["Read", { file_path: "tests/cart.test.ts" }],
    ["Bash", { command: "bun test tests" }],
    ["Bash", { command: "bun test tests/cart.test.ts 2>&1 | tail -15" }],
    ["Bash", { command: "git diff" }],
    ["Bash", { command: "git status && git log --oneline -5" }],
    ["Bash", { command: "git diff main" }],
    ["Bash", { command: "cat src/cart.ts" }],
    ["Bash", { command: "grep -n subtotal src/cart.ts" }],
    ["Bash", { command: "python3 -c \"print('make the discount whole cents')\"" }],
    ["Bash", { command: "cd /work/claude-verification-harness && bun test tests" }],
  ])("allows %s %j", (tool, input) => {
    expect(denied(guard(tool, input))).toBe(false);
  });
});

describe("try", () => {
  test("opens Claude on the ticket with CLAUDE_FLAGS and MODEL passed through", () => {
    sh(`mkdir -p bin && printf '#!/bin/sh\\necho "$@"\\n' > bin/claude && chmod +x bin/claude`);
    const r = sh(`PATH="$PWD/bin:$PATH" MODEL=haiku CLAUDE_FLAGS="--setting-sources project,local" bash harness/try.sh 03`);
    rmSync(join(repo, "bin"), { recursive: true, force: true });
    expect(r.out.trim()).toBe("--setting-sources project,local --model haiku --permission-mode dontAsk /ticket 03");
  });

  test.skipIf(!Bun.which("tmux"))("tmux opens three tickets and the verdict pane, even with pane-base-index 1", () => {
    const tmp = mkdtempSync(join(tmpdir(), "harness-tmux-"));
    const env = `TMUX= TMUX_TMPDIR="${tmp}" PATH="$PWD/bin:$PATH"`;
    sh(`mkdir -p bin && printf '#!/bin/sh\\nsleep 30\\n' > bin/claude && chmod +x bin/claude`);
    sh(`${env} tmux -f /dev/null new-session -d -s seed \\; set -g base-index 1 \\; set -g pane-base-index 1`);
    sh(`${env} bash harness/tmux.sh </dev/null`);
    const panes = sh(`${env} tmux list-panes -t harness -F '#{pane_start_command}'`).out;
    sh(`${env} tmux kill-server; git worktree remove --force .worktrees/ticket-01; git worktree remove --force .worktrees/ticket-02; git worktree remove --force .worktrees/ticket-03`);
    rmSync(join(repo, "bin"), { recursive: true, force: true });
    rmSync(tmp, { recursive: true, force: true });
    for (const n of ["01", "02", "03"]) expect(panes).toContain(`try.sh ${n}`);
    expect(panes).toContain("VERDICTS");
  });
});

describe("after-edit hook", () => {
  const afterEdit = (file: string) => sh("bun .claude/hooks/after-edit.ts", repo, JSON.stringify({ tool_input: { file_path: file } }));

  test("a failing gate after a src edit goes back to Claude as additionalContext", () => {
    writeFileSync(join(repo, "src/cart.ts"), readFileSync(join(repo, "src/cart.ts"), "utf8") + "\nexport const n = parseFloat('1.5');\n");
    const r = afterEdit("src/cart.ts");
    restoreSrc();
    expect(JSON.parse(r.out).hookSpecificOutput.additionalContext).toContain("cents stay whole numbers");
  });

  test("a clean edit, or one outside src, says nothing", () => {
    expect(afterEdit("src/cart.ts").out).toBe("");
    expect(afterEdit("README.md").out).toBe("");
  });
});

describe("guidance and the reviewer", () => {
  const frontmatter = (path: string) => readFileSync(join(ROOT, path), "utf8").split("---")[1];

  test("the money rule loads only for files in src/", () => {
    const fm = frontmatter(".claude/rules/money.md");
    expect(fm).toMatch(/paths:\s*\n\s*- "src\/\*\*\/\*\.ts"/);
  });

  test("the money rule names exactly what the cents gate refuses", () => {
    const rule = readFileSync(join(ROOT, ".claude/rules/money.md"), "utf8");
    const gate = readFileSync(join(ROOT, "harness/gates.sh"), "utf8").match(/cents stay whole numbers"\s+'! grep -nE "([^"]+)"/)![1];
    for (const word of gate.split("|")) expect(rule).toContain(`\`${word}\``);
  });

  test("the reviewer subagent has no tool that edits", () => {
    const tools = frontmatter(".claude/agents/reviewer.md").match(/^tools:(.*)$/m)![1].split(",").map((t) => t.trim());
    expect(tools.filter((t) => /^(Edit|Write|MultiEdit|NotebookEdit)$/.test(t))).toEqual([]);
  });

  test("editing the rule or the reviewer on a ticket turns the tamper gate RED", () => {
    startTicket("01");
    useSolution("01");
    writeFileSync(join(repo, ".claude/rules/money.md"), "anything goes\n");
    const r = verify();
    sh("git checkout -q -- .claude/rules");
    restoreSrc();
    expect(r.out).toContain("GATE FAILED: tests, holdout and harness unchanged");
  });
});
