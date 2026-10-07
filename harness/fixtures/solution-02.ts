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

const FREE_SHIPPING_OVER_CENTS = 5000;

export function shipping(cart: Cart): number {
  if (cart.items.length === 0) return 0;
  const counted = cart.items.filter((i) => !i.sku.startsWith("GIFT-")).reduce((sum, i) => sum + lineCents(i), 0);
  return counted > FREE_SHIPPING_OVER_CENTS ? 0 : cart.shippingCents;
}

export function total(cart: Cart): number {
  return subtotal(cart) + shipping(cart);
}

export function formatCents(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const abs = Math.abs(cents);
  const dollars = Math.floor(abs / 100);
  const rest = String(abs % 100).padStart(2, "0");
  return `${sign}$${dollars}.${rest}`;
}
