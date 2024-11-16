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
  const priceInUnderlying = Number(event.args.price);
  const wethPrice = Number(event.args.oraclePrice);
  const price = BigInt(
    BigNumber(priceInUnderlying)
      .dividedBy(1e18)
      .multipliedBy(BigNumber(wethPrice).dividedBy(1e18))
      .multipliedBy(1e18)
      .toNumber()
  );

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
