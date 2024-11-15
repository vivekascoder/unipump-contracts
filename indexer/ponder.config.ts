import { createConfig } from "@ponder/core";
import { http } from "viem";

import { ExampleContractAbi } from "./abis/ExampleContractAbi";
import { UniPumpCreatorAbi } from "./abis/UniPumpCreatorAbi";

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
      address: "0x4844d08A4B2dD5a2db165C02cFBc9676B51b92aF",
      startBlock: 17954653,
    },
  },
});
