---
name: factory-build
description: Implements an approved plan test-first, applies the named repo skills, and runs the repo's gate script, quoting the gate line verbatim in the status comment. Use as the build stage, after a plan has been approved (or was auto-approve-eligible).
---

# factory-build

Invoked as `/factory-build <N>`. No push, no `gh` access; the runner
commits and pushes what's in the worktree after you stop; you only edit
files inside this worktree and write the artifact files below.

## 1. Read the inputs

- `.factory/runs/issue-<N>/issue.json`, `triage.json`, `plan.json`,
  `plan-comment.md`: the approved plan (AC-n, NG-n, files, tests, repo
  skills to apply, gate level).
- `.factory/runs/issue-<N>/revise.md`, present only when a human sent
  `/factory revise <text>` on the PR: a change to make this round, even if
  the plan is already built. `revision.md` beside it holds every earlier
  round; honour all of it, and stop at step 5 if it crosses a non-goal.
- Already in your context pack: the charter, the route's skills, the plan's files.
- The repo skills named in the plan (`.claude/skills/<name>/SKILL.md`):
  read and follow them; they encode repo-specific rules you don't know.

## 2. Build to the plan's proof, smallest change

Read `plan.json`'s `proof` (absent means `test`).

- **`test`**: for each AC, write its named test first, watch it fail for the
  right reason, then write the smallest change that makes it pass.
- **`check`**: no test file is expected. For each AC, run the plan's named
  check command against your change and confirm it proves that AC (e.g. a
  repo-specific audit script reports the fixed line, a prose lint reports
  clean, a link check finds no dead link). Re-run every named check before
  step 3, not just the one for the AC you just touched.

Either way: do not touch a file outside the plan's "files to touch" list
without a real reason; if you find you need to, that's a signal to stop and
ask (step 5), not to quietly expand scope. Never cross a non-goal (NG-n);
those are binding.

Apply every repo skill named in the plan as you go, not as an afterthought.

## 3. Run the gate

Run `.factory/gates.sh` (or the narrower `gate_level` the plan named).
Quote the exact gate line (the command and its pass/fail output) verbatim
in the status comment. Do not paraphrase or summarize a failure as "some
tests failed"; show the line that failed.

If the gate fails and you can see why, fix it and re-run. Stop after 3
failed gate runs: write `"status": "red"` and `"outcome": "blocked"` with the
reason in `summary`, and quote the failing gate line in the status comment.
A human looks at a blocked build; don't leave it for `factory-verify` to find.

## 4. UI route: capture screenshots

Only when `triage.json`'s `type` is `ui`: read
`.claude/skills/factory-build/references/ui-route.md` and follow it before step 6.

## 5. Escape hatch: back to needs-info mid-build

If the plan turns out to rest on a wrong assumption, or you hit a decision
only a human can make, stop here rather than guessing:

- Write `.factory/runs/issue-<N>/question-comment.md` with the
  `factory-comment` skill's `question.md` template.
- Write `.factory/runs/issue-<N>/build.json` with `"status": "needs-info"`.
- Leave the worktree and any partial commits as they are; the runner
  preserves both the worktree and the current stage so build can resume
  from here once the question is answered, instead of starting over.

## 6. Write the outputs

Write `.factory/runs/issue-<N>/status-comment.md` using the
`factory-comment` skill's `status.md` template (stage `build`, progress
`3/5`, the gate line, one-line detail). Then write
`.factory/runs/issue-<N>/build.json`:

```json
{
  "status": "green",
  "gate_line": "FACTORY_GATES: status=GREEN passed=1 failed=0 skipped=0",
  "rounds": 1
}
```

`outcome` is optional: `complete` (default), `blocked` (a human must look; reason in `summary`),
or `failed`. Only the `ui` route adds `screenshots`. No other fields are allowed [enforced: stop-artifact.sh].

`status` is one of `green`, `red` (gate still red after 3 runs, see step 3),
or `needs-info` (see step 5). Write `"rounds": 1`: the runner counts
build attempts itself and replaces the value. Leave the worktree exactly as you want
it committed; the runner commits and pushes it verbatim.
