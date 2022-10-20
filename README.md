# ERC5164

Repository containing various implementations of EIP-5164, an interface defining cross-chain execution between EVM-based blockchains.

## Deployed Contracts

### Ethereum Goerli -> Optimism Goerli

| Network         | Contract                                                                               | Address                                                                                                                               |
| --------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToOptimismRelayer.sol](./src/ethereum-optimism/EthereumToOptimismRelayer.sol) | [0x56f0bA8EA5a317521057722f94b714Ca6A0373C4](https://goerli.etherscan.io/address/0x56f0bA8EA5a317521057722f94b714Ca6A0373C4)          |
| Optimism Goerli | [EthereumToOptimismExecutor](./src/ethereum-optimism/EthereumToOptimismExecutor.sol)   | [0x7f13836f80E1db095f97365B743d2CaB8Fac0b02](https://goerli-optimism.etherscan.io/address/0x7f13836f80E1db095f97365B743d2CaB8Fac0b02) |
| Optimism Goerli | [Greeter](./test/contracts/Greeter.sol)                                                | [0x316CEFdEB914Ab4E88e7C59b59Fd01d53624165d](https://goerli-optimism.etherscan.io/address/0x316CEFdEB914Ab4E88e7C59b59Fd01d53624165d) |

### Ethereum Goerli -> Polygon Mumbai

| Network         | Contract                                                                          | Address                                                                                                                         |
| --------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToPolygonRelayer](./src/ethereum-polygon/EthereumToPolygonRelayer.sol)   | [0x0B903B48B1c8f74c26425Ff04bD9241c1Ff4B804](https://goerli.etherscan.io/address/0x0B903B48B1c8f74c26425Ff04bD9241c1Ff4B804)    |
| Polygon Mumbai  | [EthereumToPolygonExecutor](./src/ethereum-polygon/EthereumToPolygonExecutor.sol) | [0xE5b60180C3094ead8E4e793c13e7A53C5623b77C](https://mumbai.polygonscan.com/address/0xE5b60180C3094ead8E4e793c13e7A53C5623b77C) |
| Polygon Mumbai  | [Greeter](./test/contracts/Greeter.sol)                                           | [0xB1475EEeE82123FAa4f611f0a78b4E62e802aECE](https://mumbai.polygonscan.com/address/0xB1475EEeE82123FAa4f611f0a78b4E62e802aECE) |

## Example transactions

### Ethereum Goerli -> Optimism Goerli

| Network         | Call        | Transaction hash                                                                                                                                                                 |
| --------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | relayCalls  | [0x5bd2c3512e7187d536439c9a029411cd38ae327de960407c8f7f2d625c389f5f](https://goerli.etherscan.io/tx/0x5bd2c3512e7187d536439c9a029411cd38ae327de960407c8f7f2d625c389f5f)          |
| Optimism Goerli | setGreeting | [0x6bb337a3f74cbdd6d60d9f6c2080d003f4938092444ca72089466d6aa596b3de](https://goerli-optimism.etherscan.io/tx/0x6bb337a3f74cbdd6d60d9f6c2080d003f4938092444ca72089466d6aa596b3de) |

### Ethereum Goerli -> Polygon Mumbai

| Network         | Call        | Transaction hash                                                                                                                                                           |
| --------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | relayCalls  | [0x184eec2fafa86efe9362aa59264295e306ae718a64472eb2f8ab7ce421bf949f](https://goerli.etherscan.io/tx/0x184eec2fafa86efe9362aa59264295e306ae718a64472eb2f8ab7ce421bf949f)    |
| Polygon Mumbai  | setGreeting | [0x61ad32d64b7105d830e199300bfc8d119fa78deb831c3fa79d1bea0cc0869176](https://mumbai.polygonscan.com/tx/0x61ad32d64b7105d830e199300bfc8d119fa78deb831c3fa79d1bea0cc0869176) |
