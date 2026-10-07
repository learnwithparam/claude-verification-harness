import { expect, test } from "bun:test";
import { newCart, shipping, total, type LineItem } from "../src/cart";

const item = (sku: string, cents: number): LineItem => ({ sku, name: sku, unitCents: cents, qty: 1 });

test("$50.01 of items ships free", () => {
  expect(shipping(newCart([item("LAMP", 5001)]))).toBe(0);
});

test("exactly $50.00 of items still pays shipping", () => {
  expect(shipping(newCart([item("LAMP", 5000)]))).toBe(599);
});

test("the $50 counts items only, never the shipping itself", () => {
  expect(total(newCart([item("LAMP", 4900)]))).toBe(4900 + 599);
});

test("gift cards (sku starting GIFT-) do not count towards the $50", () => {
  expect(shipping(newCart([item("GIFT-50", 5000), item("PEN", 300)]))).toBe(599);
});

test("an empty cart still ships nothing", () => {
  expect(shipping(newCart())).toBe(0);
});
