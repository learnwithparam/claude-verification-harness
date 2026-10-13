---
name: factory-retro
description: Reads a finished run (merged, closed by a human, or given up on after too many verify rejections) and proposes at most one lesson or skill edit, or none. Use as the last stage, after the run has already reached its final outcome; it never changes the run's result.
---

# factory-retro

Invoked as `/factory-retro <N>`. Read-only: no code edit, no push, no `gh`
access. Runs after the outcome is already decided, purely to capture
something worth remembering for next time.

## 1. Read the inputs

- `.factory/runs/issue-<N>/issue.json` and every stage artifact and comment
  that exists for this run (`triage.json`, `plan.json`, `build.json`,
  `verdict.json`, their `-comment.md` files), whatever the run actually
  produced before it ended.
- The lessons already recorded are in your context pack: don't repeat one.

## 2. Decide whether there is a lesson

Look for one concrete, reusable thing this run's outcome teaches: a plan
that missed an acceptance criterion, a gate that caught something verify's
skill should check earlier, a skill instruction that was ambiguous or
missing and caused a rejection or a human close. Most runs teach nothing
new; saying so is a valid, expected result.

Propose at most one of:
- **a lesson**: a short, general statement for `.factory/memory/lessons.md`
  (not a summary of this specific run);
- **a skill edit**: a named skill (e.g. `factory-build`) and the specific
  wording change that would have prevented the outcome.

Never propose both, and never propose more than one of either. If nothing
rises above "specific to this one issue," propose none.

## 3. Write the output

Write `.factory/runs/issue-<N>/retro.json`:

```json
{ "lesson": "{{lesson_text_or_omit}}", "skill_name": "{{skill_or_omit}}", "skill_edit": "{{edit_text_or_omit}}", "outcome": "complete", "summary": "{{one_line}}" }
```

Omit `lesson` and `skill_name`/`skill_edit` entirely when you are proposing
nothing; never propose a lesson and a skill edit together. Then write
`.factory/runs/issue-<N>/retro-comment.md`: one or two sentences on what, if
anything, you propose and why. Nothing here is applied automatically; a
later `factory learn` run reviews proposals like this one and, if it
agrees, opens a PR.
