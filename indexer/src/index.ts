import { ponder } from "@/generated";
import { UniPumpCreatorSales, minBucket } from "../ponder.schema";
import { bigint } from "@ponder/core";
import { BigNumber } from "bignumber.js";

ponder.on("UniPumpCreator:TokenSaleCreated", async ({ event, context }) => {
  const { db } = context;

  await db.insert(UniPumpCreatorSales).values({
    memeTokenAddress: event.args.token,
    isUSDCToken0: event.args.iswethToken0,
    name: event.args.name,
    symbol: event.args.symbol,
    twitter: event.args.twitter,
    discord: event.args.discord,
    bio: event.args.bio,
    imageUri: event.args.imageUri,
    createdBy: event.args.createdBy,
    createdAt: event.block.timestamp,
  });
});

ponder.on("UniPump:PriceChange", async ({ event, context }) => {
  const min = Math.floor(Number(event.args.timestamp) / 60) * 60;
  const priceInUnderlying = BigNumber(Number(event.args.price)).dividedBy(1e18);
  const wethPrice = BigNumber(Number(event.args.oraclePrice)).dividedBy(1e18);
  const price = priceInUnderlying.multipliedBy(wethPrice).toString();

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
      low: Math.min(Number(row.low), Number(price)).toString(),
      high: Math.max(Number(row.high), Number(price)).toString(),
      average: (
        (Number(row.average) * Number(row.count) + Number(price)) /
        (Number(row.count) + 1)
      ).toString(),
      count: row.count + 1,
    }));
});
