// A checkout cart. Every amount is an integer number of cents, so no float ever touches a price.

export interface LineItem {
  sku: string;
  name: string;
  unitCents: number;
  qty: number;
}

export interface Cart {
  items: LineItem[];
  shippingCents: number;
  code?: string;
}

export const STANDARD_SHIPPING_CENTS = 599;

export function newCart(items: LineItem[] = []): Cart {
  return { items, shippingCents: STANDARD_SHIPPING_CENTS };
}

export function addItem(cart: Cart, item: LineItem): Cart {
  return { ...cart, items: [...cart.items, item] };
}

export function lineCents(item: LineItem): number {
  return item.unitCents * item.qty;
}

export function subtotal(cart: Cart): number {
  return cart.items.reduce((sum, item) => sum + lineCents(item), 0);
}

export function shipping(cart: Cart): number {
  return cart.items.length === 0 ? 0 : cart.shippingCents;
}

const WELCOME5_MIN_CENTS = 2500;

function discount(cart: Cart): number {
  const items = subtotal(cart);
  if (cart.code === "SAVE10") return Math.round((items * 10) / 100);
  if (cart.code === "WELCOME5") return 500;
  return 0;
}

export function applyCode(cart: Cart, code: string): Cart {
  const normalised = code.toUpperCase();
  if (normalised !== "SAVE10" && normalised !== "WELCOME5") throw new Error(`Unknown code ${code}`);
  if (normalised === "WELCOME5" && subtotal(cart) < WELCOME5_MIN_CENTS) throw new Error("WELCOME5 needs $25.00 of items");
  return { ...cart, code: normalised };
}

export function total(cart: Cart): number {
  return subtotal(cart) - discount(cart) + shipping(cart);
}

export function formatCents(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const abs = Math.abs(cents);
  const dollars = Math.floor(abs / 100);
  const rest = String(abs % 100).padStart(2, "0");
  return `${sign}$${dollars}.${rest}`;
}
