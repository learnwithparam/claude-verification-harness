---
name: factory-verify
description: Verifies a build against its plan by proving it (a test that fails without the change) and running the factory-reviewer subagent, then writes a pass, reject, or uncertain verdict with per-AC evidence and a test-that-bites proof. Use as the verification stage, after build finished.
---

# factory-verify

Invoked as `/factory-verify <N>`. No push, no `gh` access; write files,
the runner posts the verdict and moves the issue's label.

## 1. Read the inputs

- `.factory/runs/issue-<N>/issue.json`, `plan.json`, `plan-comment.md`,
  `build.json`: the plan's AC-n and NG-n, and what build reports it did.
- `gate.json` and `proof.json` in the same directory: what the runner
  measured on this tree. Do not re-run the gates; the runner refuses a red one
  before verify. Holdout tests are the runner's too: never read their paths.
- The worktree at its current state. Write `"rounds": 1`; the runner
  counts verify rounds itself and replaces the value.

## 2. UI route: the visual check

Only when `triage.json`'s `type` is `ui`: read
`.claude/skills/factory-verify/references/ui-route.md` and follow it alongside step 3, not instead of it.

## 3. Prove it, then review it

The runner has run the revert check and the gate on this tree. Read
`.factory/runs/issue-<N>/proof.json` and quote `gate.json`'s `line`:
- `bites`: the new tests failed with the change reverted. Confirm from
  `tail` that they failed for the stated reason, not a compile error.
- `passes-without`: the tests pass without the change, so prove nothing: reject.
- `no-tests`, `skipped`, `unavailable`, or no file: read
  `.claude/skills/factory-verify/references/prove.md` and prove it yourself.

An AC like "removing X makes the tests fail" is a mutation: run it with
.factory/mutate.sh on a copy as prove.md says, never by editing the worktree.

Every AC needs a command you ran or the proof's output as evidence; a
crossed NG-n is a reject. When uncertain, the verdict is `uncertain`; a
refused command is not uncertainty.

Dispatch to `factory-reviewer` in the foreground and wait for it
[enforced: guard-paths.sh] (fresh context, read-only): correctness, security
(injection, authz, secrets), and whether the diff crosses any NG-n. Collect
its findings verbatim, do not soften them. Drop only
one the diff did not introduce (the base branch has it too): name it in the
comment as a separate issue, never as a reason to reject. The runner drops any
finding whose `where` is not on a line the diff changed, so give every
`must`/`should` finding a `file:line`.

## 4. Decide the verdict

- **pass**: every AC has evidence, the gate is green, no NG-n crossed, no
  blocking reviewer finding, and (on the `ui` route) no blocking step 2
  finding. A `must`/`should` finding at confidence 3 or more, or a
  non-`pass` criterion, refuses the verdict and routes to a human.
- **reject**: any AC unproven, gate red, an NG-n crossed, or a blocking
  finding. The runner retries `factory-build` up to twice, then routes to
  a human automatically; just report `reject` honestly each time.
- **uncertain**: the proof or the reviewer could not reach a confident
  answer, or round limit hit. Route to a human, don't guess.

## 5. Write the outputs

Use `factory-comment`'s `verdict.md` template for
`.factory/runs/issue-<N>/verdict-comment.md`: per-AC pass/fail with the
evidence command and result, the test-that-bites (name, failing output on
the base branch, passing output here), reviewer findings verbatim, a summary of
non-goals respected, and (on reject) which round this is.

Then write `.factory/runs/issue-<N>/verdict.json`:

```json
{
  "result": "pass",
  "rounds": 1,
  "findings": [],
  "criteria": [{ "id": "AC-1", "status": "pass" }]
}
```

A finding is `{ "severity": "must|should|could", "confidence": 0-5, "what": "...",
"where": "file:line", "why": "...", "fix": "..." }` (`what` is required). A
criterion is `pass`, `fail`, or `unverified` (with a `gap`); AC ids come from the
plan and are never renumbered. No other top-level fields are allowed [enforced: stop-artifact.sh];
the runner also refuses an unknown finding or criterion field. The file must be one JSON object
under 16 KiB.

Set `outcome` to `blocked` (with a `summary`) only if you could not review at
all. `result` is `pass`, `reject`, or `uncertain`; `findings` is the
reviewer's list verbatim plus any from step 2 (empty array if none); the
retry and escalation rules are step 4's, not repeated here.
