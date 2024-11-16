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
      address: "0xB846cd0c9AaA337c4a87ECF2f0464e2eCA4AC26a",
      startBlock: 18010417,
    },
    UniPump: {
      network: "base-sepolia",
      abi: UniPumpAbi,
      address: "0x1824A6A774599F746EeBF689F05C12DAd96AeA80",
      startBlock: 18010417,
    },
  },
});
