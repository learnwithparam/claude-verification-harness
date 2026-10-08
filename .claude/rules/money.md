---
paths:
  - "src/**/*.ts"
---

# Money in src/

- Every amount is an integer number of cents. Never use `toFixed`, `parseFloat` or a float price.
- Turn cents into a dollar string only with `formatCents`, which already exists.
