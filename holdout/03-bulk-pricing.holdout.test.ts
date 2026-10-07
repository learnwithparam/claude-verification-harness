import { expect, test } from "bun:test";
import { newCart, subtotal, type LineItem } from "../src/cart";

const line = (sku: string, unitCents: number, qty: number): LineItem => ({ sku, name: sku, unitCents, qty });

test("exactly 3 of an item gets 15% off that item", () => {
  expect(subtotal(newCart([line("CUP", 1000, 3)]))).toBe(2550);
});

test("2 of an item pays full price", () => {
  expect(subtotal(newCart([line("CUP", 1000, 2)]))).toBe(2000);
});

test("the 15% discount rounds half up to the cent", () => {
  expect(subtotal(newCart([line("PEN", 330, 3)]))).toBe(841);
});

test("the same item on two lines counts together towards 3", () => {
  expect(subtotal(newCart([line("CUP", 1000, 2), line("CUP", 1000, 1)]))).toBe(2550);
});

test("other items in the cart keep full price", () => {
  expect(subtotal(newCart([line("CUP", 1000, 3), line("TEE", 1999, 1)]))).toBe(2550 + 1999);
});
