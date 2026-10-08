# Checkout cart

A small checkout cart in Bun and TypeScript.

- Code lives in `src/cart.ts`. Tickets live in `tickets/` and start with `/ticket <number>`.
- Run the visible tests with `bun test tests`.
- Only `src/` is yours to change. When you stop, a reviewer runs gates and acceptance tests you cannot
  see, and sends back the reason if the work is not done.
- The rules for money in `src/` load from `.claude/rules/money.md` when you open a file there.
