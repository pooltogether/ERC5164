# ERC-5164

EIP-5164 specifies how smart contracts on one chain can message contracts on another. Transport layers, such as bridges, will have their own EIP-5164 implementations. This repository includes implementations for: Ethereum to Polygon, Ethereum to Optimism, and Ethereum to Arbitrum. All three use the 'native' bridge solutions.

The EIP is currently in the Review stage: https://eips.ethereum.org/EIPS/eip-5164

Feedback and PR are welcome!

## How to use

To use ERC-5164 to send messages your contract code will need to:

- On the sending chain, send a message to the MessageDispatcher `dispatchMessage` or `dispatchMessageBatch` function
- Listen for messages from the corresponding MessageExecutor(s) on the receiving chain.

_The listener will need to be able to unpack the original sender address (it's appended to calldata). We recommend inheriting from the included [`ExecutorAware.sol`](./src/abstract/ExecutorAware.sol) contract._

**Note**

For most bridges, you only have to call `dispatchMessage` or `dispatchMessageBatch` to have messages executed by the MessageExecutor. However, Arbitrum requires an EOA to process the dispatch. We will review this below.

## How it works

1. A smart contract on the sending chain calls `dispatchMessage` or `dispatchMessageBatch` on the MessageDispatcher..
2. The corresponding MessageExecutor(s) on the receiving chain will execute the message or batch of Message structs. The address of the original dispatcher on the sending chain is appended to the message data.
3. Any smart contract can receive messages from a MessageExecutor, but they should use the original dispatcher address for authentication.

**Note: this specification does not require messages to be executed in order**

## Dispatching

### Dispatch a message

To dispatch a message from Ethereum to the L2 of your choice, you have to interact with the [ISingleMessageDispatcher](./src/interfaces/ISingleMessageDispatcher.sol) contract and call the following function.

```solidity
/**
 * @notice Dispatch a message to the receiving chain.
 * @dev Must compute and return an ID uniquely identifying the message.
 * @dev Must emit the `MessageDispatched` event when successfully dispatched.
 * @param toChainId ID of the receiving chain
 * @param to Address on the receiving chain that will receive `data`
 * @param data Data dispatched to the receiving chain
 * @return bytes32 ID uniquely identifying the message
 */
function dispatchMessage(
  uint256 toChainId,
  address to,
  bytes calldata data
) external returns (bytes32);

```

- `toChainId`: id of the chain to which you want to dispatch the message
- `to`: address of the contract that will receive the message
- `data`: message that you want to be executed on L2

### Dispatch a batch messages

To dispatch a batch of messages from Ethereum to the L2 of your choice, you have to interact with the [IBatchedMessageDispatcher](./src/interfaces/IBatchedMessageDispatcher.sol) contract and call the following function.

```solidity
/**
 * @notice Dispatch `messages` to the receiving chain.
 * @dev Must compute and return an ID uniquely identifying the `messages`.
 * @dev Must emit the `MessageBatchDispatched` event when successfully dispatched.
 * @param toChainId ID of the receiving chain
 * @param messages Array of Message dispatched
 * @return bytes32 ID uniquely identifying the `messages`
 */
function dispatchMessageBatch(uint256 toChainId, MessageLib.Message[] calldata messages)
  external
  returns (bytes32);

```

- `toChainId`: id of the chain to which you want to dispatch the message
- `messages`: array of Message that you want to be executed on L2

```solidity
/**
 * @notice Message data structure
 * @param to Address that will be dispatched on the receiving chain
 * @param data Data that will be sent to the `to` address
 */
struct Message {
  address to;
  bytes data;
}

```

#### Example

```solidity
MessageDispatcherOptimism _messageDispatcher = 0x3F3623aB84a86410096f53051b82aA41773A4480;
address _greeter = 0x19c8f7B8BA7a151d6825924446A596b6084a36ae;

_messageDispatcher.dispatchMessage(
  420,
  _greeter,
  abi.encodeWithSignature("setGreeting(string)", "Hello from L1")
);
```

Code:

- [script/bridge/BridgeToOptimismGoerli.s.sol](script/bridge/BridgeToOptimismGoerli.s.sol)
- [script/bridge/BridgeToMumbai.s.sol](script/bridge/BridgeToMumbai.s.sol)

### Arbitrum Dispatch

Arbitrum requires an EOA to submit a bridge transaction. The Ethereum to Arbitrum ERC-5164 MessageDispatcher `dispatchMessage` implementation is therefore split into two actions:

1. Message to MessageDispatcher `dispatchMessage` is fingerprinted and stored along with their `messageId`.
2. Anyone may call MessageDispatcher `processMessage` to send a previously fingerprinted dispatched message.

The `processMessage` function requires the same transaction parameters as the Arbitrum bridge. The [Arbitrum SDK](https://github.com/offchainlabs/arbitrum-sdk) is needed to properly estimate the gas required to execute the message on L2.

```solidity
/**
 * @notice Process message that has been dispatched.
 * @dev The transaction hash must match the one stored in the `dispatched` mapping.
 * @dev `_from` is passed as `callValueRefundAddress` cause this address can cancel the retryably ticket.
 * @dev We store `_message` in memory to avoid a stack too deep error.
 * @param _messageId ID of the message to process
 * @param _from Address who dispatched the `_data`
 * @param _to Address that will receive the message
 * @param _data Data that was dispatched
 * @param _refundAddress Address that will receive the `excessFeeRefund` amount if any
 * @param _gasLimit Maximum amount of gas required for the `_messages` to be executed
 * @param _maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
 * @param _gasPriceBid Gas price bid for L2 execution
 * @return uint256 Id of the retryable ticket that was created
 */
function processMessage(
  bytes32 messageId,
  address from,
  address to,
  bytes calldata data,
  address refundAddress,
  uint256 gasLimit,
  uint256 maxSubmissionCost,
  uint256 gasPriceBid
) external payable returns (uint256);

```

#### Arbitrum Dispatch Example

```typescript
  const greeterAddress = await getContractAddress('Greeter', ARBITRUM_GOERLI_CHAIN_ID, 'Forge');

  const greeting = 'Hello from L1';
  const messageData = new Interface(['function setGreeting(string)']).encodeFunctionData(
    'setGreeting',
    [greeting],
  );

  const nextNonce = (await messageDispatcherArbitrum.nonce()).add(1);

  const encodedMessageId = keccak256(
    defaultAbiCoder.encode(
      ['uint256', 'address', 'address', 'bytes'],
      [nextNonce, deployer, greeterAddress, messageData],
    ),
  );

  const executeMessageData = new Interface([
    'function executeMessage(address,bytes,bytes32,uint256,address)',
  ]).encodeFunctionData('executeMessage', [
    greeterAddress,
    messageData,
    encodedMessageId,
    GOERLI_CHAIN_ID,
    deployer,
  ]);

...

  const { deposit, gasLimit, maxSubmissionCost } = await l1ToL2MessageGasEstimate.estimateAll(
    {
      from: messageDispatcherArbitrumAddress,
      to: messageExecutorAddress,
      l2CallValue: BigNumber.from(0),
      excessFeeRefundAddress: deployer,
      callValueRefundAddress: deployer,
      data: executeMessageData,
    },
    baseFee,
    l1Provider,
  );

  await messageDispatcherArbitrum.dispatchMessage(
    ARBITRUM_GOERLI_CHAIN_ID,
    greeterAddress,
    messageData,
  );

...

await messageDispatcherArbitrum.processMessage(
    messageId,
    deployer,
    greeterAddress,
    messageData,
    deployer,
    gasLimit,
    maxSubmissionCost,
    gasPriceBid,
    {
      value: deposit,
    },
  );
```

Code: [script/bridge/BridgeToArbitrumGoerli.ts](script/bridge/BridgeToArbitrumGoerli.ts)

## Execution

#### Execute message

Once the message has been bridged it will be executed by the [MessageExecutor](./src/interfaces/IMessageExecutor.sol) contract.

#### Authenticate messages

To ensure that the messages originate from the MessageExecutor contract, your contracts can inherit from the [ExecutorAware](./src/abstract/ExecutorAware.sol) abstract contract.

It makes use of [EIP-2771](https://eips.ethereum.org/EIPS/eip-2771) to authenticate the message forwarder (i.e. the MessageExecutor) and has helper functions to extract from the calldata the original sender and the `messageId` of the dispatched message.

```solidity
/**
 * @notice Check which executor this contract trust.
 * @param _executor Address to check
 */
function isTrustedExecutor(address _executor) public view returns (bool);

/**
  * @notice Retrieve messageId from message data.
  * @return _msgDataMessageId ID uniquely identifying the message that was executed
  */
function _messageId() internal pure returns (bytes32 _msgDataMessageId)

/**
  * @notice Retrieve fromChainId from message data.
  * @return _msgDataFromChainId ID of the chain that dispatched the messages
  */
function _fromChainId() internal pure returns (uint256 _msgDataFromChainId);

/**
 * @notice Retrieve signer address from message data.
 * @return _signer Address of the signer
 */
function _msgSender() internal view returns (address payable _signer);

```

## Deployed Contracts

### Ethereum Goerli -> Arbitrum Goerli

| Network         | Contract                                                                                     | Address                                                                                                                      |
| --------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToArbitrumDispatcher.sol](./src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol) | [0xC1d6d4ce8e34D2126C85b05569868AF4E43AE39B](https://goerli.etherscan.io/address/0xC1d6d4ce8e34D2126C85b05569868AF4E43AE39B) |
| Arbitrum Goerli | [EthereumToArbitrumExecutor](./src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol)         | [0xaAc4688AB7AD2c0CbC51E9674D53Bf394910aF6a](https://goerli.arbiscan.io/address/0xaAc4688AB7AD2c0CbC51E9674D53Bf394910aF6a)  |
| Arbitrum Goerli | [Greeter](./test/contracts/Greeter.sol)                                                      | [0x8531Ba6686c7Bc1573a3b4AfeDc138862299cCC8](https://goerli.arbiscan.io/address/0x8531Ba6686c7Bc1573a3b4AfeDc138862299cCC8)  |

### Ethereum Goerli -> Optimism Goerli

| Network         | Contract                                                                                     | Address                                                                                                                               |
| --------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToOptimismDispatcher.sol](./src/ethereum-optimism/EthereumToOptimismDispatcher.sol) | [0x3F3623aB84a86410096f53051b82aA41773A4480](https://goerli.etherscan.io/address/0x3F3623aB84a86410096f53051b82aA41773A4480)          |
| Optimism Goerli | [EthereumToOptimismExecutor](./src/ethereum-optimism/EthereumToOptimismExecutor.sol)         | [0x02EBD3Fc1012a3794A350CdFc2336D780431E7Cb](https://goerli-optimism.etherscan.io/address/0x02EBD3Fc1012a3794A350CdFc2336D780431E7Cb) |
| Optimism Goerli | [Greeter](./test/contracts/Greeter.sol)                                                      | [0x19c8f7B8BA7a151d6825924446A596b6084a36ae](https://goerli-optimism.etherscan.io/address/0x19c8f7B8BA7a151d6825924446A596b6084a36ae) |

### Ethereum Goerli -> Polygon Mumbai

| Network         | Contract                                                                              | Address                                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToPolygonDispatcher](./src/ethereum-polygon/EthereumToPolygonDispatcher.sol) | [0xCD6A49066CC76F01Ed7da2138e51AD16Ba9d959F](https://goerli.etherscan.io/address/0xCD6A49066CC76F01Ed7da2138e51AD16Ba9d959F)    |
| Polygon Mumbai  | [EthereumToPolygonExecutor](./src/ethereum-polygon/EthereumToPolygonExecutor.sol)     | [0xC0D5b4B1104f587Dd48A5c3aFe25a90a7eE63d66](https://mumbai.polygonscan.com/address/0xC0D5b4B1104f587Dd48A5c3aFe25a90a7eE63d66) |
| Polygon Mumbai  | [Greeter](./test/contracts/Greeter.sol)                                               | [0x95DD92c3B28791BE29Cc3cB7D8a8D07025f2B2Ca](https://mumbai.polygonscan.com/address/0x95DD92c3B28791BE29Cc3cB7D8a8D07025f2B2Ca) |

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

- Fork tests to dispatch messages from Ethereum to Arbitrum:

  ```
  yarn fork:startDispatchMessageBatchArbitrumMainnet
  ```

- Fork tests to execute messages on Arbitrum:

  ```
  yarn fork:startExecuteMessageBatchArbitrumMainnet
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

| Network         | Message         | Transaction hash                                                                                                                                                        |
| --------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | dispatchMessage | [0x0a01b7c55f8a808d9ca6c8cb565c7aa6f30490b0685c7406d86af83e1b231caa](https://goerli.etherscan.io/tx/0x0a01b7c55f8a808d9ca6c8cb565c7aa6f30490b0685c7406d86af83e1b231caa) |
| Ethereum Goerli | processMessage  | [0x10e714e603d7d52fe54da3ceb63e7f99357dca91de94fb5257f95456716ddccc](https://goerli.etherscan.io/tx/0x10e714e603d7d52fe54da3ceb63e7f99357dca91de94fb5257f95456716ddccc) |
| Arbitrum Goerli | executeMessage  | [0x9149a46cc78efabe0d885eccd83c1c7c5c359ec076aade731fdd892703e3869f](https://goerli.arbiscan.io/tx/0x9149a46cc78efabe0d885eccd83c1c7c5c359ec076aade731fdd892703e3869f)  |

#### Ethereum Goerli to Optimism Goerli

```
yarn bridge:optimismGoerli
```

It takes about 5 minutes for the message to be bridged to Optimism Goerli.

##### Example transaction

| Network         | Message         | Transaction hash                                                                                                                                                                 |
| --------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | dispatchMessage | [0xcecd5846d2965c4b257bc60e8d306f939fade9c1b809d53af362c22f7d6d47fa](https://goerli.etherscan.io/tx/0xcecd5846d2965c4b257bc60e8d306f939fade9c1b809d53af362c22f7d6d47fa)          |
| Optimism Goerli | executeMessage  | [0xf07ea8fd12791ea1b6b11c1d67085278986356abcaf91591a4cb7067e7a20f15](https://goerli-optimism.etherscan.io/tx/0xf07ea8fd12791ea1b6b11c1d67085278986356abcaf91591a4cb7067e7a20f15) |

#### Ethereum Goerli to Polygon Mumbai

```
yarn bridge:mumbai
```

It takes about 30 minutes for the message to be bridged to Mumbai.

##### Example transaction

| Network         | Message         | Transaction hash                                                                                                                                                           |
| --------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | dispatchMessage | [0x552769ad086d0845d518fa4e194c4b03c45922100cfd9265686848dfa3c00b01](https://goerli.etherscan.io/tx/0x552769ad086d0845d518fa4e194c4b03c45922100cfd9265686848dfa3c00b01)    |
| Polygon Mumbai  | executeMessage  | [0x07dd16e6756b9c4fb6749545abb75e019519016aa2dcdac00c71948e55ccb151](https://mumbai.polygonscan.com/tx/0x07dd16e6756b9c4fb6749545abb75e019519016aa2dcdac00c71948e55ccb151) |

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
