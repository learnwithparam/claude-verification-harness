# UI route: the visual check

Read `build.json`'s `screenshots`
array against the repo design skill's state list (`.claude/skills/*-design/SKILL.md`,
if it has one; otherwise the states the AC-n list names).
Every state x viewport (390, 1440) x theme (light, dark) combination the
plan's AC-n list covers needs an entry; a gap is a `must` finding at
confidence 5, and the verdict cannot be `pass`. Read each screenshot (a
worktree file, not a URL) against the five-criterion rubric
(hierarchy, 390px thumb reach, AA contrast, token use, restraint, each
1-5); any criterion under 4 is a `should` finding naming the screenshot,
the criterion and the score, and three or more such findings become a
`must`. This runs alongside, not instead of, step 3: a `ui`-typed issue
still needs a green gate and every AC proven.
