T ?= 01

.PHONY: doctor verify try tmux reset check

doctor:        ## the tools the demo needs
	@bash harness/doctor.sh

verify:        ## the harness's verdict on this checkout
	@bash harness/verify.sh

try:           ## Claude on one ticket in its own worktree: make try T=01
	@bash harness/try.sh $(T)

tmux:          ## three Claudes on three tickets, plus a verdict pane
	@bash harness/tmux.sh

reset:         ## remove ticket worktrees, branches and verdicts
	@bash harness/reset.sh

check:         ## the repo's own gate: visible tests, then the harness self-test
	@bun test tests && bun test --timeout 30000 ./harness/harness.test.ts
