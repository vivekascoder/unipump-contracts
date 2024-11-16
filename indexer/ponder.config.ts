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
      address: "0xADA0Ff7C8F108E311Ca7c82845A1b8ef26E90e11",
      startBlock: 18010713,
    },
    UniPump: {
      network: "base-sepolia",
      abi: UniPumpAbi,
      address: "0xe7f06CC969f37958BCAf6AF7C9f93b251338EA80",
      startBlock: 18010713,
    },
  },
});
