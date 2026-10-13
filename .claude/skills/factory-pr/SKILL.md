---
name: factory-pr
description: Fills the PR body from the plan and the passing verdict's evidence, following the target repo's PR template when one exists. Use as the final stage, after verify returned pass, right before the runner opens a draft PR.
---

# factory-pr

Invoked as `/factory-pr <N>`. No push, no `gh` access; you write the PR
body to a file; the runner runs `git push` and `gh pr create --draft` with
it. Only reachable after `factory-verify` wrote `result: "pass"`.

## 1. Read the inputs

- `.factory/runs/issue-<N>/issue.json`, `plan.json`, `plan-comment.md`,
  `verdict.json`, `verdict-comment.md`: the goal, AC-n, and the evidence
  that each one passed.
- `.github/pull_request_template.md` or `.github/PULL_REQUEST_TEMPLATE.md`
  in the target repo, if present. It belongs to that repo, not to this
  skill; never create or edit it here.

## 2. Fill the body

If a PR template exists, fill its sections from the plan and verdict; do
not invent sections it doesn't have or drop ones it does. If no template
exists, use this structure (the same shape as the one this template ships
in `.github/pull_request_template.md`):

```markdown
## Summary
{{one_line_goal}}

Closes #{{issue_number}}

## Plan
{{link_to_plan_comment}}: AC-1 {{criterion}}, verified by {{evidence_command}} ...

## Gate evidence
{{gate_line_verbatim}}

## Verify verdict
{{link_to_verdict_comment}}: {{test_that_bites_summary}}

## Risk and rollback
{{risk_level_from_plan}}: {{rollback_note}}
```

Keep it factual and short: what changed, how each AC was checked, what was
deliberately left out (the non-goals). Do not restate the whole verdict
comment; link to it instead of copying it.

## 3. UI route: embed the screenshots

Skip this step unless `triage.json`'s `type` is `ui`. Read `build.json`'s
`screenshots` array. Add a `## Screenshots` section after `## Gate
evidence`, one row per state, light theme by default:

```markdown
## Screenshots
| State | 390px | 1440px |
|---|---|---|
| {{state}} | ![]({{raw_url_390_light}}) | ![]({{raw_url_1440_light}}) |
```

`{{raw_url}}` is `https://raw.githubusercontent.com/<repo>/factory/issue-<N>/<path>`,
built from `.factory/config.json`'s `repo` and this issue's number; the
branch is already pushed by the time this stage runs. Mention in a line
below the table that dark-theme captures exist at the same paths with
`-dark` in place of `-light`, for a reviewer who wants them.

## 4. Write the outputs

Write `.factory/runs/issue-<N>/pr-body.md` with the filled body above;
this is the only file this stage reads back. The runner opens the PR as a
draft, titled from the issue itself (`<issue title> (#<N>)`), with this
file as the body, then sets the issue's label to `factory:in-review`.
