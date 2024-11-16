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
      address: "0xE354E322598db07b38f0FCF173bd09958984c138",
      startBlock: 18008055,
    },
    UniPump: {
      network: "base-sepolia",
      abi: UniPumpAbi,
      address: "0x368ec5615143676f245510faE0fd97eE000aaA80",
      startBlock: 18008055,
    },
  },
});
