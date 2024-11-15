import { ponder } from "@/generated";
import { UniPumpCreatorSales, minBucket } from "../ponder.schema";
import { bigint } from "@ponder/core";

ponder.on("UniPumpCreator:TokenSaleCreated", async ({ event, context }) => {
  const { db } = context;

  await db.insert(UniPumpCreatorSales).values({
    memeTokenAddress: event.args.token,
    isUSDCToken0: event.args.isUSDCToken0,
    name: event.args.name,
    symbol: event.args.symbol,
    twitter: event.args.twitter,
    discord: event.args.discord,
    bio: event.args.bio,
    createdBy: event.args.createdBy,
  });
});

ponder.on("UniPump:PriceChange", async ({ event, context }) => {
  const min = Math.floor(Number(event.args.timestamp) / 60) * 60;
  const price = event.args.price;

  await context.db
    .insert(minBucket)
    .values({
      id: min,
      open: price,
      close: price,
      low: price,
      high: price,
      average: price,
      count: 1,
      tokenAddress: event.args.tokenAddress,
    })
    .onConflictDoUpdate((row) => ({
      close: price,
      low: BigInt(Math.min(Number(row.low), Number(price))),
      high: BigInt(Math.max(Number(row.high), Number(price))),
      average:
        (row.average * BigInt(row.count) + price) / (BigInt(row.count) + 1n),
      count: row.count + 1,
    }));
});
