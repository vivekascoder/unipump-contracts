import { onchainTable } from "@ponder/core";

export const example = onchainTable("example", (t) => ({
  id: t.text().primaryKey(),
  name: t.text(),
}));

export const UniPumpCreatorSales = onchainTable("UniPumpCreatorSales", (t) => ({
  memeTokenAddress: t.hex().primaryKey(),
  isUSDCToken0: t.boolean(),
  name: t.text(),
  symbol: t.text(),
  twitter: t.text(),
  discord: t.text(),
  bio: t.text(),
  createdBy: t.hex(),
  createdAt: t.bigint().notNull(),
}));

export const minBucket = onchainTable("minBucket", (t) => ({
  id: t.integer().primaryKey(),
  open: t.bigint().notNull(),
  close: t.bigint().notNull(),
  low: t.bigint().notNull(),
  high: t.bigint().notNull(),
  average: t.bigint().notNull(),
  count: t.integer().notNull(),
  tokenAddress: t.hex().notNull(),
}));
