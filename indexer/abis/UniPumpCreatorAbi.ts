export const UniPumpCreatorAbi = [
  {
    type: "constructor",
    inputs: [
      { name: "_poolManager", type: "address", internalType: "address" },
      { name: "_weth", type: "address", internalType: "address" },
      {
        name: "_create2Deployer",
        type: "address",
        internalType: "address",
      },
      { name: "_unipump", type: "address", internalType: "address" },
      { name: "_feeHook", type: "address", internalType: "address" },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "DEFAULT_FEE",
    inputs: [],
    outputs: [{ name: "", type: "uint24", internalType: "uint24" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "createTokenSale",
    inputs: [
      { name: "_name", type: "string", internalType: "string" },
      { name: "_symbol", type: "string", internalType: "string" },
      { name: "_twitter", type: "string", internalType: "string" },
      { name: "_discord", type: "string", internalType: "string" },
      { name: "_bio", type: "string", internalType: "string" },
      { name: "_imageUri", type: "string", internalType: "string" },
    ],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "TokenSaleCreated",
    inputs: [
      {
        name: "token",
        type: "address",
        indexed: false,
        internalType: "address",
      },
      {
        name: "iswethToken0",
        type: "bool",
        indexed: false,
        internalType: "bool",
      },
      {
        name: "name",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "symbol",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "twitter",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "discord",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "bio",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "imageUri",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "createdBy",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
] as const;
