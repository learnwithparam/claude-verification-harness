---
name: factory-operator
description: Use the software factory to create, assign and monitor a task. Use when a coding agent needs to hand work to the factory, label an issue factory:ready, or read what the factory is waiting on. Not used by the factory's own stages.
---
<!-- Ported from owainlewis/machinist@3943516 skills/machinist/SKILL.md:1-75 (MIT, Copyright (c) 2026 Owain Lewis). Deviations: machinist run/submit become the factory:ready label; status comes from factory inbox and factory logs. -->

# Factory operator

The factory turns a GitHub issue into a planned, built, independently verified pull
request. It never merges the pull request.

## Core model

- A task is one GitHub issue in the target repository.
- Assigning a task means labelling the issue `factory:ready`. The watcher picks it up.
- Label the same issue again to continue interrupted work. The factory reuses the existing
  branch, worktree and pull request.
- When `FACTORY_ISSUE` is set, you are already inside a factory run. Follow the assigned
  stage and do not label or start another run.

## Create a task

Reuse a supplied issue when it is open and belongs to the current repository. Otherwise
create one issue with `gh issue create`. Keep it focused on one observable outcome and keep
the user's constraints. Do not invent implementation details the request does not decide.

```sh
gh issue create --title "<short outcome>" --body "<problem, outcome, constraints, and acceptance evidence>"
```

Use the issue URL that GitHub returns for every later command.

## Assign a task

```sh
gh issue edit <N> --add-label factory:ready
```

The label has no effect unless a watcher runs for this repository (`factory doctor` says
whether the loop can run).

## Report status

```sh
factory inbox --repo <owner/name> --json
factory logs <N> --repo <owner/name> --json
```

The inbox lists what waits for a human. The logs show one run's events, one JSON object per
line. Then read the linked pull request and its checks.

- For blocked work, fix the reported cause or answer the question, then comment
  `/factory retry` on the issue.
- For completed work, hand the pull request to a person. Never merge unless that person
  explicitly decides to.
- Approving a plan (`/factory approve`) is a human decision. Do not post it on their behalf.

When reporting status, include the issue URL, the pull request URL when there is one, the
checks, and the blocker or next human action.
