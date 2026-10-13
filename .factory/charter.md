# claude-verification-harness factory charter

## Risk

- **low**: a docs-only change.
- **medium**: any change to `src/`, which always needs `/factory approve`.
- **high**: any change to `harness/`, `holdout/` or `.claude/`, which needs approval and a cited rule.

## Protected

- `harness/**`, `holdout/**` and `tests/**`: the harness grades the agent with these, so an agent never edits them.
- Amounts are integer cents everywhere in `src/cart.ts`.
