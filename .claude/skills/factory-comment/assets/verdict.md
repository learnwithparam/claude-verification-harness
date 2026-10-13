<!-- factory:verdict v1 -->
## Verdict: {{pass|reject|uncertain}}

### Acceptance criteria evidence
{{#each ac}}
- **AC-{{n}}:** {{pass|fail|unverified}}: {{evidence_command_and_result}}
{{/each}}

### The test that bites
`{{test_name}}` fails on the base branch ({{failing_output_snippet}}), passes here
(`{{command}}` → {{passing_output_snippet}}).

### Reviewer findings
{{#each findings}}
- {{finding}}
{{/each}}
{{#unless findings}}
None.
{{/unless}}

### Non-goals respected
{{ng_respected_summary}}

{{#if reject}}
Sending back to build (round {{round}} of 2) with the findings above.
{{/if}}
{{#if uncertain}}
Uncertain: flagging for a human rather than guessing.
{{/if}}
