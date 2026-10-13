# UI route: capture screenshots

The repo's design skill
(`.claude/skills/*-design/SKILL.md`, if it has one) names the state list,
rubric and playwright-cli commands; follow it. For
every state x viewport (390, 1440) x theme (light, dark) the plan's AC-n
list covers, run the real built page through real auth and data (no mocked
render), save the PNG at `docs/design/reviews/issue-<N>/<state>-<viewport>-<theme>.png`
and stage it (`git add docs/design/reviews/`, the runner pushes it like any
other file), then record `{ "state", "viewport", "theme", "path" }` in
`build.json`'s `screenshots` array. Only the `ui` route adds that array. An empty or
missing one is not done; `factory-verify` rejects it for missing coverage.
