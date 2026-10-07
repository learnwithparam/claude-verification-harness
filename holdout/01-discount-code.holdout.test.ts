import { expect, test } from "bun:test";
import * as cart from "../src/cart";

// The ticket's code is not on main yet, so reach it through the module rather than a named import.
const applyCode = (c: cart.Cart, code: string): cart.Cart => (cart as any).applyCode(c, code);
const items = (cents: number) => cart.newCart([{ sku: "BAG", name: "Bag", unitCents: cents, qty: 1 }]);

test("SAVE10 takes 10% off the items and never off the shipping", () => {
  expect(cart.total(applyCode(items(5000), "SAVE10"))).toBe(4500 + 599);
});

test("codes are case-insensitive", () => {
  expect(cart.total(applyCode(items(5000), "save10"))).toBe(4500 + 599);
});

test("the 10% discount rounds half up to the cent", () => {
  expect(cart.total(applyCode(items(1995), "SAVE10"))).toBe(1795 + 599);
});

test("WELCOME5 takes $5.00 off an order with at least $25.00 of items", () => {
  expect(cart.total(applyCode(items(2500), "WELCOME5"))).toBe(2000 + 599);
});

test("WELCOME5 on less than $25.00 of items throws", () => {
  expect(() => applyCode(items(2499), "WELCOME5")).toThrow();
});

test("a second code replaces the first, codes never stack", () => {
  expect(cart.total(applyCode(applyCode(items(3000), "SAVE10"), "WELCOME5"))).toBe(2500 + 599);
});

test("an unknown code throws", () => {
  expect(() => applyCode(items(5000), "FREE100")).toThrow();
});

test("applyCode does not change the cart it was given", () => {
  const before = items(5000);
  applyCode(before, "SAVE10");
  expect(cart.total(before)).toBe(5000 + 599);
});
