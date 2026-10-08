# Claude Code verification harness

Claude says "done, tests pass". This repo checks that claim before you ever see it. When Claude stops,
a Stop hook runs gates and acceptance tests Claude cannot read or change. A RED sends the reason back,
and Claude fixes its own work. After three REDs the ticket goes to a human.

It is plain Claude Code, on a tiny checkout cart in Bun and TypeScript: `CLAUDE.md`, one path-scoped
rule, permission rules, three hooks, one skill, one reviewer subagent, and a harness of gates and
holdout tests. Free to clone and try.

## Before you start

You need `git`, [`bun`](https://bun.sh) and [Claude Code](https://code.claude.com). `tmux` is optional.

```bash
git clone https://github.com/learnwithparam/claude-verification-harness
cd claude-verification-harness
make doctor
```

Opening Claude Code in this folder runs the hooks in `.claude/hooks/` on your machine, after you trust
the folder. Read them first: they are short. Run `claude` here once and accept the trust dialog before
`make try`: until then Claude Code ignores the repo's allow rules. `docs/run-2026-10-07.md` shows what
five rehearsal runs did.

## What is in it

| Piece | What it does |
| --- | --- |
| `CLAUDE.md` | Guidance loaded every session: how to run things. Claude may ignore it. |
| `.claude/rules/money.md` | Guidance loaded only when Claude opens a file in `src/`: amounts stay whole cents. |
| `.claude/settings.json` | Enforced: permission rules and the three hooks. A `Read` deny covers the Read tool only. |
| `.claude/hooks/guard.ts` | PreToolUse. Denies reading the holdout, editing tests or the harness, rewriting `src/` with a script (the after-edit gates would miss it), and git commands that read other commits. A `Read` deny rule alone does not stop `cat` in Bash. |
| `.claude/hooks/after-edit.ts` | PostToolUse. Runs the gates after each edit to `src/` and hands failures back as context. |
| `.claude/hooks/stop.ts` | Stop. Runs `harness/verify.sh`. RED exits 2 with the reason; the third RED hands over to a human. |
| `.claude/skills/ticket` | `/ticket 01` starts a ticket. Only you can run it. |
| `.claude/agents/reviewer.md` | A read-only subagent: after GREEN it reads the ticket and the diff for what no test checks. |
| `harness/gates.sh` | One line per gate: whole cents, no `.only`, visible tests, nothing tampered with. |
| `holdout/` | The product owner's acceptance tests. Claude is graded on them and never shown them. |
| `tickets/` | Three small tickets, written as loosely as real ones. |

## Watch it say no

```bash
make verify            # GREEN on main
make try T=01          # Claude on ticket 01, in its own worktree with no holdout/ on disk
```

Claude implements the ticket, the visible tests pass, and it says done. The Stop hook answers with the
name of an acceptance test it failed, and Claude goes back to work without you typing anything.

## Add a gate

Pick a rule your team keeps repeating in review. Add one `gate` line to `harness/gates.sh`, then
`make verify`. Every Claude run from now on meets it.

## Run it yourself

```bash
make try T=02          # or T=03
make tmux              # three Claudes on three tickets, plus a pane of verdicts
make reset             # clean up worktrees, branches and verdicts
```

Then copy `.claude/` and `harness/` into your own repo and change `gates.sh` to your stack.

## What this demo simplifies

- The holdout sits in the repo, behind hooks, so you can read it. In production it lives where the
  agent cannot reach at all: CI or a separate repo.
- The hooks and the harness live in the same working tree as Claude. The guard is a denylist and a
  determined agent can get round it. In production the verdict that counts runs in CI, from a commit
  the agent did not write.
- `make check` tests the harness itself, and runs in CI on every push.
