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
      address: "0x4844d08A4B2dD5a2db165C02cFBc9676B51b92aF",
      startBlock: 17954653,
    },
    UniPump: {
      network: "base-sepolia",
      abi: UniPumpAbi,
      address: "0xa6B8734C40613235d6Ae3946CE898c514283Aa80",
      startBlock: 17954653,
    },
  },
});
