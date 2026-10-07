---
name: ticket
description: Start work on one ticket from tickets/, by number.
argument-hint: <number>
disable-model-invocation: true
allowed-tools: Bash(bash harness/start-ticket.sh *)
---

!`bash harness/start-ticket.sh $ARGUMENTS`

Implement the ticket above in `src/`. Run `bun test tests` while you work. When the ticket is done,
say so and stop: a reviewer checks your work when you stop.
