# Discount codes at checkout

Customers want to type a discount code at checkout.

- `SAVE10` takes 10% off.
- `WELCOME5` takes $5 off.

Add `applyCode(cart: Cart, code: string): Cart` to `src/cart.ts`. It returns a new cart with the code
applied, and `total(cart)` includes the discount. An unknown code throws an `Error`.
