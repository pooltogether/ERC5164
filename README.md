# ERC-5164

EIP-5164 specifies how smart contracts on one chain can call contracts on another. Transport layers, such as bridges, will have their own EIP-5164 implementations. This repository includes implementations for: Ethereum to Polygon, Ethereum to Optimism, and Ethereum to Arbitrum. All three use the 'native' bridge solutions.

The EIP is currently in the Review stage: https://eips.ethereum.org/EIPS/eip-5164

Feedback and PR are welcome!

## How to use

To use ERC-5164 to send messages your contract code will need to:

- On the sending chain, send a batch of calls to the CrossChainRelayer `relayCalls` function
- Listen for calls from the corresponding CrossChainExecutor(s) on the receiving chain.

*The listener will need to be able to unpack the original sender address (it's appended to calldata). We recommend inheriting from the included [`ExecutorAware.sol`](./src/abstract/ExecutorAware.sol) contract.*

**Note**

For most bridges, you only have to call `relayCalls` to have messages executed by the CrossChainExecutor. However, Arbitrum requires an EOA to process the relay. We will review this below.

## How it works

1. A smart contract on the sending chain calls `relayCalls` on the CrossChainRelayer; it is passed an array of Call structs.
2. The corresponding CrossChainExecutor(s) on the receiving chain will execute the batch of Call structs. The address of the original caller on the sending chain is appended to the call data.
3. Any smart contract can receive calls from a CrossChainExecutor, but they should use the original caller address for authentication.

**Note: this specification does not require messages to be executed in order**

## Relaying

### Relay calls

To relay a message from Ethereum to the L2 of your choice, you have to interact with the [CrossChainRelayer](./src/interfaces/ICrossChainRelayer.sol) contract and call the `relayCalls` function:

```solidity
/**
 * @notice Relay the calls to the receiving chain.
 * @dev Must increment a `nonce` so that the batch of calls can be uniquely identified.
 * @dev Must emit the `RelayedCalls` event when successfully called.
 * @dev May require payment. Some bridges may require payment in the native currency, so the function is payable.
 * @param calls Array of calls being relayed
 * @param gasLimit Maximum amount of gas required for the `calls` to be executed
 * @return uint256 Nonce to uniquely idenfity the batch of calls
 */
function relayCalls(CallLib.Call[] calldata calls, uint256 gasLimit)
  external
  payable
  returns (uint256);

```

`calls` is an array of calls that you want to be executed on L2:

```solidity
/**
 * @notice Call data structure
 * @param target Address that will be called on the receiving chain
 * @param data Data that will be sent to the `target` address
 */
struct Call {
  address target;
  bytes data;
}

```

`gasLimit` is the maximum amount of gas that will be needed to execute these calls.

#### Example

```solidity
CrossChainRelayerOptimism _crossChainRelayer = 0xB577c479D6D7eC677dB6c349e6E23B7bfE303295;
address _greeter = 0xd55052D3617f8ebd5DeEb7F0AC2D6f20d185Bc9d;

CallLib.Call[] memory _calls = new CallLib.Call[](1);

_calls[0] = CallLib.Call({
  target: _greeter,
  data: abi.encodeWithSignature("setGreeting(string)", "Hello from L1")
});

_crossChainRelayer.relayCalls(_calls, 1000000);
```

Code:

- [script/bridge/BridgeToOptimismGoerli.s.sol](script/bridge/BridgeToOptimismGoerli.s.sol)
- [script/bridge/BridgeToMumbai.s.sol](script/bridge/BridgeToMumbai.s.sol)

### Arbitrum Relay

Arbitrum requires an EOA to submit a bridge transaction. The Ethereum to Arbitrum ERC-5164 CrossChainRelayer `relayCalls` implementation is therefore split into two actions:

1. Calls to CrossChainRelayer `relayCalls` are fingerprinted and stored along with their nonce.
2. Anyone may call CrossChainRelayer `processCalls` to send a previously fingerprinted relayed call.

The `processCalls` function requires the same transaction parameters as the Arbitrum bridge. The [Arbitrum SDK](https://github.com/offchainlabs/arbitrum-sdk) is needed to properly estimate the gas required to execute the message on L2.

```solidity
/**
 * @notice Process calls that have been relayed.
 * @dev The transaction hash must match the one stored in the `relayed` mapping.
 * @param nonce Nonce of the batch of calls to process
 * @param calls Array of calls being processed
 * @param sender Address who relayed the `calls`
 * @param gasLimit Maximum amount of gas required for the `calls` to be executed
 * @param maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
 * @param gasPriceBid Gas price bid for L2 execution
 * @return uint256 Id of the retryable ticket that was created
 */
function processCalls(
  uint256 nonce,
  CallLib.Call[] calldata calls,
  address sender,
  uint256 gasLimit,
  uint256 maxSubmissionCost,
  uint256 gasPriceBid
) external payable returns (uint256);

```

#### Arbitrum Relay Example

```typescript
const greeting = 'Hello from L1';
const callData = new Interface(['function setGreeting(string)']).encodeFunctionData(
  'setGreeting',
  [greeting],
);

const calls: ICrossChainRelayer.CallStruct[] = [
  {
    target: greeterAddress,
    data: callData,
  },
];

...

const maxGas = await l1ToL2MessageGasEstimate.estimateRetryableTicketGasLimit({
  from: crossChainRelayerArbitrumAddress,
  to: crossChainExecutorAddress,
  l2CallValue: BigNumber.from(0),
  excessFeeRefundAddress: deployer,
  callValueRefundAddress: deployer,
  data: executeCallsData,
});

await crossChainRelayerArbitrum.relayCalls(calls, maxGas);

...

await crossChainRelayerArbitrum.processCalls(
  relayCallsNonce,
  calls,
  deployer,
  maxGas,
  maxSubmissionCost,
  gasPriceBid,
  {
    value: callValue,
  },
);
```

Code: [script/bridge/BridgeToArbitrumGoerli.ts](script/bridge/BridgeToArbitrumGoerli.ts)

## Execution

#### Execute calls

Once the message has been bridged it will be executed by the [CrossChainExecutor](./src/interfaces/ICrossChainExecutor.sol) contract.

#### Authenticate calls

To ensure that the calls originate from the CrossChainExecutor contract, your contracts can inherit from the [ExecutorAware](./src/abstract/ExecutorAware.sol) abstract contract.

It makes use of [EIP-2771](https://eips.ethereum.org/EIPS/eip-2771) to authenticate the call forwarder (i.e. the CrossChainExecutor) and has helper functions to extract from the calldata the original sender and the nonce of the relayed call.

```solidity
/**
 * @notice Check which executor this contract trust.
 * @param _executor Address to check
 */
function isTrustedExecutor(address _executor) public view returns (bool);

/**
 * @notice Retrieve signer address from call data.
 * @return _signer Address of the signer
 */
function _msgSender() internal view returns (address payable _signer);

/**
 * @notice Retrieve nonce from call data.
 * @return _callDataNonce Nonce uniquely identifying the message that was executed
 */
function _nonce() internal pure returns (uint256 _callDataNonce);

```

## Deployed Contracts

### Ethereum Goerli -> Arbitrum Goerli

| Network         | Contract                                                                               | Address                                                                                                                      |
| --------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToArbitrumRelayer.sol](./src/ethereum-arbitrum/EthereumToArbitrumRelayer.sol) | [0x7460fDb4db23C7287c67122A31661b753081e80a](https://goerli.etherscan.io/address/0x7460fDb4db23C7287c67122A31661b753081e80a) |
| Arbitrum Goerli | [EthereumToArbitrumExecutor](./src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol)   | [0x18771cC0bbcA24d3B28C040669DCc7b5Ffba30FB](https://goerli.arbiscan.io/address/0x18771cC0bbcA24d3B28C040669DCc7b5Ffba30FB)  |
| Arbitrum Goerli | [Greeter](./test/contracts/Greeter.sol)                                                | [0xa1d913940B8dbb7bDB1F68D8E9C54484D575FefC](https://goerli.arbiscan.io/address/0xa1d913940B8dbb7bDB1F68D8E9C54484D575FefC)  |

### Ethereum Goerli -> Optimism Goerli

| Network         | Contract                                                                               | Address                                                                                                                               |
| --------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToOptimismRelayer.sol](./src/ethereum-optimism/EthereumToOptimismRelayer.sol) | [0xB577c479D6D7eC677dB6c349e6E23B7bfE303295](https://goerli.etherscan.io/address/0xB577c479D6D7eC677dB6c349e6E23B7bfE303295)          |
| Optimism Goerli | [EthereumToOptimismExecutor](./src/ethereum-optimism/EthereumToOptimismExecutor.sol)   | [0x7A4c111CEBfA573f785BFa4ED144f70b1ab519a0](https://goerli-optimism.etherscan.io/address/0x7A4c111CEBfA573f785BFa4ED144f70b1ab519a0) |
| Optimism Goerli | [Greeter](./test/contracts/Greeter.sol)                                                | [0xd55052D3617f8ebd5DeEb7F0AC2D6f20d185Bc9d](https://goerli-optimism.etherscan.io/address/0xd55052D3617f8ebd5DeEb7F0AC2D6f20d185Bc9d) |

### Ethereum Goerli -> Polygon Mumbai

| Network         | Contract                                                                          | Address                                                                                                                         |
| --------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToPolygonRelayer](./src/ethereum-polygon/EthereumToPolygonRelayer.sol)   | [0xB867e4E65eb093dC86D9E4Fd6622dDA58583B7F1](https://goerli.etherscan.io/address/0xB867e4E65eb093dC86D9E4Fd6622dDA58583B7F1)    |
| Polygon Mumbai  | [EthereumToPolygonExecutor](./src/ethereum-polygon/EthereumToPolygonExecutor.sol) | [0x5A1Ca26f637dad188ea95A92C2b262226E2a2646](https://mumbai.polygonscan.com/address/0x5A1Ca26f637dad188ea95A92C2b262226E2a2646) |
| Polygon Mumbai  | [Greeter](./test/contracts/Greeter.sol)                                           | [0xe0B149a4fb0a40eC13531596f824cFa523445280](https://mumbai.polygonscan.com/address/0xe0B149a4fb0a40eC13531596f824cFa523445280) |

## Development

### Installation

You may have to install the following tools to use this repository:

- [Yarn](https://yarnpkg.com/getting-started/install) to handle dependencies
- [Foundry](https://github.com/foundry-rs/foundry) to compile and test contracts
- [direnv](https://direnv.net/) to handle environment variables
- [lcov](https://github.com/linux-test-project/lcov) to generate the code coverage report

Install dependencies:

```
yarn
```

### Env

Copy `.envrc.example` and write down the env variables needed to run this project.

```
cp .envrc.example .envrc
```

Once your env variables are setup, load them with:

```
direnv allow
```

### Compile

Run the following command to compile the contracts:

```
yarn compile
```

### Test

We use [Hardhat](https://hardhat.org) to run Arbitrum fork tests. All other tests are being written in Solidity and make use of [Forge Standard Library](https://github.com/foundry-rs/forge-std).

To run Forge unit and fork tests:

```
yarn test
```

To run Arbitrum fork tests, use the following commands:

- Fork tests to relay calls from Ethereum to Arbitrum:

  ```
  yarn fork:startRelayCallsArbitrumMainnet
  ```

- Fork tests to execute calls on Arbitrum:

  ```
  yarn fork:startExecuteCallsArbitrumMainnet
  ```

### Coverage

Forge is used for coverage, run it with:

```
yarn coverage
```

You can then consult the report by opening `coverage/index.html`:

```
open coverage/index.html
```

### Deployment

You can use the following commands to deploy on testnet.

#### Ethereum Goerli to Arbitrum Goerli bridge

```
yarn deploy:arbitrumGoerli
```

#### Ethereum Goerli to Optimism Goerli bridge

```
yarn deploy:optimismGoerli
```

#### Ethereum Goerli to Polygon Mumbai bridge

```
yarn deploy:mumbai
```

### Bridging

You can use the following commands to bridge from Ethereum to a layer 2 of your choice.

It will set the greeting message in the [Greeter](./test/contracts/Greeter.sol) contract to `Hello from L1` instead of `Hello from L2`.

#### Ethereum Goerli to Arbitrum Goerli

```
yarn bridge:arbitrumGoerli
```

It takes about 15 minutes for the message to be bridged to Arbitrum Goerli.

##### Example transaction

| Network         | Call         | Transaction hash                                                                                                                                                        |
| --------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | relayCalls   | [0x102ae324d996fdeadf666d1f6f00db00c73be632c8b115cf6f2ab901fd1ca7f7](https://goerli.etherscan.io/tx/0x102ae324d996fdeadf666d1f6f00db00c73be632c8b115cf6f2ab901fd1ca7f7) |
| Ethereum Goerli | processCalls | [0x34876c7553b4618170e1c95aaa30daf79e4ddb6436cb7e317215ea0e3593dbcc](https://goerli.etherscan.io/tx/0x34876c7553b4618170e1c95aaa30daf79e4ddb6436cb7e317215ea0e3593dbcc) |
| Arbitrum Goerli | executeCalls | [0xc74b9570949b941ec1f1a020c1d988614448947e6f2de691e2031304bb76bd0c](https://goerli.arbiscan.io/tx/0xc74b9570949b941ec1f1a020c1d988614448947e6f2de691e2031304bb76bd0c)  |

#### Ethereum Goerli to Optimism Goerli

```
yarn bridge:optimismGoerli
```

It takes about 5 minutes for the message to be bridged to Optimism Goerli.

##### Example transaction

| Network         | Call         | Transaction hash                                                                                                                                                                 |
| --------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | relayCalls   | [0xe3864c4fa1f77fc0ca9ff5c5185582833049a4d8cc3cf4e30a6c53f49eaad53d](https://goerli.etherscan.io/tx/0xe3864c4fa1f77fc0ca9ff5c5185582833049a4d8cc3cf4e30a6c53f49eaad53d)          |
| Optimism Goerli | executeCalls | [0x5f73e44b9fd601b0e0031ac87ad18092a8fc621963ec8a4447062baf799d982a](https://goerli-optimism.etherscan.io/tx/0x5f73e44b9fd601b0e0031ac87ad18092a8fc621963ec8a4447062baf799d982a) |

#### Ethereum Goerli to Polygon Mumbai

```
yarn bridge:mumbai
```

It takes about 30 minutes for the message to be bridged to Mumbai.

##### Example transaction

| Network         | Call         | Transaction hash                                                                                                                                                           |
| --------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | relayCalls   | [0x069e20553358d4faba80c9b699e3be6d2331608979733260469f6c5375140058](https://goerli.etherscan.io/tx/0x069e20553358d4faba80c9b699e3be6d2331608979733260469f6c5375140058)    |
| Polygon Mumbai  | executeCalls | [0x590babab7b396ee3cae566a894f34c32daee3832d9a206ccc53576b88de49f4a](https://mumbai.polygonscan.com/tx/0x590babab7b396ee3cae566a894f34c32daee3832d9a206ccc53576b88de49f4a) |

### Code quality

[Prettier](https://prettier.io) is used to format TypeScript and Solidity code. Use it by running:

```
yarn format
```

[Solhint](https://protofire.github.io/solhint/) is used to lint Solidity files. Run it with:

```
yarn hint
```

[TypeChain](https://github.com/ethereum-ts/Typechain) is used to generates types for Hardhat scripts and tests. Generate them by running:

```
yarn typechain
```
