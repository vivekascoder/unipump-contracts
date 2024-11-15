import { createConfig } from "@ponder/core";
import { http } from "viem";
import { UniPumpCreatorAbi } from "./abis/UniPumpCreatorAbi";
import { UniPumpAbi } from "./abis/UniPumpAbi.s";

export default createConfig({
  networks: {
    "base-sepolia": {
      chainId: 84532,
      transport: http(process.env.PONDER_RPC_URL_84532),
    },
  },
  contracts: {
    UniPumpCreator: {
      network: "base-sepolia",
      abi: UniPumpCreatorAbi,
      address: "0x635f8B6CF384faC60453088ad7A6b9A468b23cA7",
      startBlock: 17967368,
    },
    UniPump: {
      network: "base-sepolia",
      abi: UniPumpAbi,
      address: "0xf8E8dE4b67DD1738Db87125e302eAFA823802a80",
      startBlock: 17967368,
    },
  },
});
