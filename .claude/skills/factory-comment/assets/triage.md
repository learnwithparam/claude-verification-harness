<!-- factory:triage v1 -->
## Triage

**Disposition:** {{disposition}} <!-- proceed | needs-info | refused | duplicate -->
**Type:** {{type}} <!-- bug | feature | docs | security | dependency -->
**Risk:** {{risk}} <!-- low | medium | high -->
**Confidence:** {{confidence}} <!-- 0.0-1.0 -->

**Done when:** {{done_when}}

**Files expected:** {{files_expected_list}}

**Gate level:** {{gate_level}}

{{#if refused}}
**Refused.** This crosses a protected boundary:

> {{charter_rule_quoted_verbatim}}

A human needs to decide this one.
{{/if}}

{{#if duplicate}}
**Duplicate of** #{{duplicate_of}}. Closing the loop here; follow that issue.
{{/if}}

{{#if needs_info}}
I can't write a checkable "done when" yet. See the question below.
{{/if}}
