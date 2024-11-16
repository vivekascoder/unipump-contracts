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
      address: "0x446d439aF3c9f12fcAB91cCf005B6C1fF7e35cC8",
      startBlock: 17998374,
    },
    UniPump: {
      network: "base-sepolia",
      abi: UniPumpAbi,
      address: "0xB1286e8447B288fbb4C8B4b86160f1adc5672A80",
      startBlock: 17998374,
    },
  },
});
