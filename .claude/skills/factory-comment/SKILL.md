---
name: factory-comment
description: Writes a factory GitHub comment (triage, question, plan, status, or verdict) from the shared templates in assets/, so every stage speaks in one voice. Use whenever another factory-* skill needs to produce a comment body or an issue-thread question for the software factory loop.
---

# factory-comment

One voice for every comment the loop posts. Every other `factory-*` skill calls
this skill instead of freehanding markdown, so a triage comment on issue #2
reads like a triage comment on issue #40.

## How to use this skill

1. Pick the template in `assets/` that matches what you're writing:
   `triage.md`, `question.md`, `plan.md`, `status.md`, `verdict.md`.
2. Fill every placeholder (`{{like_this}}`). Do not leave a placeholder in the
   output; if a field has nothing to say, write "none" or "n/a", never
   silence.
3. Keep the hidden marker on its own first line, exactly as written in the
   template (`<!-- factory:triage v1 -->`, etc.). The runner parses it; a
   missing or altered marker means the comment is invisible to the loop.
4. Write the finished comment to the file the calling skill tells you to
   (normally `.factory/runs/issue-<N>/<stage>-comment.md`). You do not call
   `gh` yourself: settings.json denies `gh` and `git push` to every stage,
   and the runner posts what you write.
5. Plain language, short sentences. No em dashes. A person reading only this
   comment, with no other context, should understand the decision and why.

## Status comments are special

Every other template produces a **new** comment each time. `status.md` is
different: the runner keeps one status comment per issue and edits it in
place (via `gh issue comment --edit`), so it never has to know your wording,
only that the marker is present. Never write "stage 2 of 5, again" as a new
comment; that is what status.md is for, and the runner owns posting it, not
you.

## Question comments (needs-info)

At most 3 numbered questions. Each question gets 2-3 lettered options, a
recommended default, and one line: "if you don't answer, I will do X." This
is the only place ambiguity is acceptable to name instead of resolve, and
only because a human is being asked to resolve it.

## Revision counters

`plan.md` carries `rev=N` in its marker. The first plan for an issue is
`rev=1`. A `/factory revise` re-run increments N and replaces the same
comment (the caller passes you the current N); never start a fresh plan
comment for a revision.

## Voice checklist before you write the file

- Would a teammate reading this on their phone understand it in one pass?
- Does every claim point at a command, a test name, or a charter rule, not a
  vibe?
- Did you quote the charter verbatim wherever you cite it, not paraphrase?
