import { describe, expect, test } from "bun:test";
import { addItem, formatCents, newCart, shipping, subtotal, total } from "../src/cart";

const mug = { sku: "MUG", name: "Mug", unitCents: 1250, qty: 2 };
const tee = { sku: "TEE", name: "T-shirt", unitCents: 1999, qty: 1 };

describe("cart", () => {
  test("subtotal adds every line", () => {
    expect(subtotal(newCart([mug, tee]))).toBe(4499);
  });

  test("total adds standard shipping", () => {
    expect(total(newCart([mug]))).toBe(2500 + 599);
  });

  test("an empty cart ships nothing and costs nothing", () => {
    const cart = newCart();
    expect(shipping(cart)).toBe(0);
    expect(total(cart)).toBe(0);
  });

  test("addItem does not change the cart it was given", () => {
    const cart = newCart([mug]);
    const bigger = addItem(cart, tee);
    expect(cart.items).toHaveLength(1);
    expect(bigger.items).toHaveLength(2);
  });

  test("formatCents prints dollars and cents", () => {
    expect(formatCents(4499)).toBe("$44.99");
    expect(formatCents(5)).toBe("$0.05");
    expect(formatCents(-250)).toBe("-$2.50");
  });
});
