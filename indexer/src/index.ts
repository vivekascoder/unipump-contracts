import { ponder } from "@/generated";
import { UniPumpCreatorSales } from "../ponder.schema";

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

// ponder.on("")
