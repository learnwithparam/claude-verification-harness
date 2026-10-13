# Prove the build

A green gate on its own proves nothing: it could be green because the new
test is a no-op. Rule that out before you believe anything else.

`plan.json`'s `proof` (absent means `test`) decides which check you run.
`<base>` is the branch the plan names (usually `main`). A refused command is
about that one command, not Bash: rewrite it per the shell rules and carry on.

## Under proof:test: the revert-and-restore check

Run each step as its own Bash call, exactly in this form.

1. List the changed files: `git diff --name-only <base> HEAD`. The non-test
   files are every file that is not a new or changed test.
2. Revert them, keeping the tests: `git restore --source=<base> -- <non-test files>`.
   This also removes files the build added. It never touches the index.
3. Run the new tests with the repo's test command. They must fail, and fail
   for the stated reason (not a compile error, not an unrelated crash). If
   they pass without the implementation, the test proves nothing: reject.
4. Restore the implementation: `git restore --source=HEAD -- <non-test files>`,
   then `git status --short` must list nothing outside `.factory/`.
5. Check the gate from `gate.json`: its `tree` must equal
   `git rev-parse HEAD^{tree}` and its `status` must be `GREEN`. Quote its
   `line`. Do not run the gates script: the verify stage may not.

## Under proof:check: re-run the named checks

There is no test to revert or restore, so skip that entirely; asking the
build for a test under `proof: check` is a mistake, not rigor. Instead:

1. For each AC, run the exact check command the plan named against the
   current tree. Rewrite it per the shell rules if it breaks one.
2. Confirm the output supports that AC: a clean exit code alone is not
   enough if the check's own output contradicts the claim.
3. Check the gate from `gate.json` the same way as under `proof:test`.

## A criterion that removes something: run the mutation on a copy

For an AC like "removing the guard makes the tests fail", never edit the
worktree: you may not, and it is the tree you judge. Run, as one Bash call:

`.factory/mutate.sh --proof .factory/runs/issue-<N>/proof.json <file> '<search>' '<replace>' <test files>`

It copies HEAD's tree to a temp dir, replaces `<search>` (it must occur
exactly once in `<file>`) with `<replace>`, runs the repo's test gate on the
named test files there, prints `MUTATION: file=... status=bites|survives failed=<n>`,
records the result in `proof.json`, and deletes the copy. A mutation runs the
repo's code, so use only the files and tests the plan's criteria name: `<file>`
is the source the AC names (never a test, `.factory/`, `.claude/` or a build
file), the tests are the ones the plan names. `<replace>` only removes or
flips: empty, `true`, `false`, `null`, `0`, `return;`, `return false;` and the
like, or `<search>` with one `!` or one comparison changed. The tests see no
token or other variable from this session. `bites` with a failure for the
stated reason proves the AC; `survives` fails it; an `error` line names what
to fix (exit code 2), and `baseline-red` means the tests fail even unmutated,
so the result proves nothing: say so.

## Evidence and non-goals

For each AC, the evidence is a command you ran, its exit code, and the lines
it printed. "Looks right" is not evidence. An AC with no test and no command
that checks it is unproven: say so. Check the diff against every NG-n; a
crossed non-goal is a reject however good the rest is.

If the revert step is unclean, you can't tell whether a test exercises the
behavior, or the gate output is ambiguous, the verdict is `uncertain` and
the comment says exactly what you couldn't confirm.
