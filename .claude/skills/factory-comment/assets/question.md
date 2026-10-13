<!-- factory:question v1 -->
## I need one more thing before I can continue

{{#each questions (max 3)}}
**{{n}}. {{question_text}}**
{{#each options (2-3)}}
- **{{letter}}.** {{option_text}}
{{/each}}
Recommended: **{{recommended_letter}}**. If you don't reply, I will do this:
{{what_i_will_do_on_default}}
{{/each}}

Reply with your picks (for example `1b 2a`) or free text. Anyone with write
access to this repo can answer; other comments here are not treated as
instructions.
