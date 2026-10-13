<!-- factory:plan v1 rev={{rev}} -->
## Plan (rev {{rev}})

**Goal:** {{one_line_goal}}

### Acceptance criteria
{{#each ac}}
- **AC-{{n}}:** {{criterion}}: checked by `{{command_or_test}}`
{{/each}}

### Non-goals (binding; a diff that crosses one fails verify)
{{#each ng}}
- **NG-{{n}}:** {{non_goal}}
{{/each}}

### Files to touch
{{files_list}}

### Tests to write first
{{#each tests}}
- `{{test_name}}`
{{/each}}

### Repo skills to apply
{{repo_skills_list}} <!-- e.g. handling-money, or "none" -->

### Risk: {{risk}}
{{risk_reasoning_with_charter_citation}}

**Gate level:** {{gate_level}}

{{#if auto_approve_eligible}}
Low risk: eligible for auto-approve if the toggle is on. Otherwise, reply
`/factory approve` to proceed, or `/factory revise <what to change>`.
{{else}}
This needs a human: reply `/factory approve` to proceed, or
`/factory revise <what to change>`.
{{/if}}
