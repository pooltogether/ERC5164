import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { L1TransactionReceipt, L1ToL2MessageGasEstimator } from '@arbitrum/sdk/';
import { getBaseFee } from '@arbitrum/sdk/dist/lib/utils/lib';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, providers } from 'ethers';
import kill from 'kill-port';

import { processL1ToL2Tx } from '../helpers/arbitrum';
import { ARBITRUM_CHAIN_ID, MAINNET_CHAIN_ID } from '../../../Constants';
import { getContractAddress } from '../../../helpers/getContract';
import { getChainName } from '../../../helpers/getChain';
import { action, error as errorLog, info, success } from '../../../helpers/log';
import { MessageDispatcherArbitrum, MessageExecutorArbitrum, Greeter } from '../../../types';
import GreeterArtifact from '../../../out/Greeter.sol/Greeter.json';

const killHardhatNode = async (port: number, chainId: number) => {
  await kill(port, 'tcp')
    .then(() => success(`Killed ${getChainName(chainId)} Hardhat node`))
    .catch((error) => {
      errorLog(`Failed to kill ${getChainName(chainId)} Hardhat node`);
      console.log(error);
    });
};

export const dispatchMessageBatch = task(
  'fork:dispatch-message-batch',
  'Dispatch a batch of messages from Ethereum to Arbitrum',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Dispatch a batch of messages from Ethereum to Arbitrum...');

  const {
    ethers: {
      getContract,
      provider: l1Provider,
      utils: { formatBytes32String, Interface },
    },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  const l2Provider = new providers.JsonRpcProvider(process.env.ARBITRUM_RPC_URL);

  info(`Dispatcher is: ${deployer}`);

  const messageDispatcherArbitrum = (await getContract(
    'MessageDispatcherArbitrum',
  )) as MessageDispatcherArbitrum;

  const messageExecutorAddress = await getContractAddress(
    'MessageExecutorArbitrum',
    ARBITRUM_CHAIN_ID,
  );

  const greeterAddress = await getContractAddress('Greeter', ARBITRUM_CHAIN_ID);

  const greeting = 'Hello from L1';
  const messageData = new Interface(['function setGreeting(string)']).encodeFunctionData(
    'setGreeting',
    [greeting],
  );

  const messages = [
    {
      to: greeterAddress,
      data: messageData,
    },
  ];

  const executeMessageBatchData = new Interface([
    'function executeMessageBatch((address,bytes)[],bytes32,uint256,address)',
  ]).encodeFunctionData('executeMessageBatch', [
    [[greeterAddress, messageData]],
    formatBytes32String(''),
    MAINNET_CHAIN_ID,
    deployer,
  ]);

  const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(l2Provider);
  const baseFee = await getBaseFee(l1Provider);

  /**
   * The estimateAll method gives us the following values for sending an L1->L2 message
   * (1) maxSubmissionCost: The maximum cost to be paid for submitting the transaction
   * (2) gasLimit: The L2 gas limit
   * (3) deposit: The total amount to deposit on L1 to cover L2 gas and L2 message value
   */
  const { deposit, gasLimit, maxSubmissionCost } = await l1ToL2MessageGasEstimate.estimateAll(
    {
      to: messageExecutorAddress,
      from: messageDispatcherArbitrum.address,
      data: executeMessageBatchData,
      l2CallValue: BigNumber.from(0),
      excessFeeRefundAddress: deployer,
      callValueRefundAddress: deployer,
    },
    baseFee,
    l1Provider,
  );

  info(`Current retryable base submission price is: ${maxSubmissionCost.toString()}`);

  const dispatchMessageBatchTransaction = await messageDispatcherArbitrum.dispatchMessageBatch(
    ARBITRUM_CHAIN_ID,
    messages,
  );
  console.log('before dispatchMessageBatchTransactionReceipt');
  const dispatchMessageBatchTransactionReceipt = await dispatchMessageBatchTransaction.wait();

  const dispatchedMessagesEventInterface = new Interface([
    'event MessageBatchDispatched(bytes32 indexed messageId, address indexed from, uint256 indexed toChainId, (address to,bytes data)[])',
  ]);

  const dispatchedMessagesEventLogs = dispatchedMessagesEventInterface.parseLog(
    dispatchMessageBatchTransactionReceipt.logs[0],
  );

  const [messageId] = dispatchedMessagesEventLogs.args;

  success('Successfully dispatched messages from Ethereum to Arbitrum!');
  info(`MessageId: ${messageId}`);

  action('Process messages from Ethereum to Arbitrum...');

  const gasPriceBid = await l2Provider.getGasPrice();

  info(`L2 gas price: ${gasPriceBid.toString()}`);

  info(`Sending greeting to L2 with ${deposit.toString()} messageValue for L2 fees:`);

  const processMessageBatchTransaction = await messageDispatcherArbitrum.processMessageBatch(
    messageId,
    messages,
    deployer,
    deployer,
    gasLimit,
    maxSubmissionCost,
    gasPriceBid,
    {
      value: deposit,
    },
  );

  const processMessageBatchTransactionReceipt = await processMessageBatchTransaction.wait();

  const processedMessagesEventInterface = new Interface([
    'event MessageBatchProcessed(bytes32 indexed messageId, address indexed sender, uint256 indexed ticketId)',
  ]);

  const processedMessagesEventLogs = processedMessagesEventInterface.parseLog(
    processMessageBatchTransactionReceipt.logs[2],
  );

  const [processedMessageId, sender, ticketId] = processedMessagesEventLogs.args;

  const receipt = await l1Provider.getTransactionReceipt(processMessageBatchTransaction.hash);
  const l1Receipt = new L1TransactionReceipt(receipt);

  const { retryableCreationId }: { retryableCreationId: string } = (
    await l1Receipt.getL1ToL2Messages(l2Provider)
  )[0];

  success('Successfully processed messages from Ethereum to Arbitrum!');
  info(`Sender: ${sender}`);
  info(`MessageId: ${processedMessageId.toString()}`);
  info(`TicketId: ${ticketId.toString()}`);
  info(`RetryableCreationId: ${retryableCreationId}`);

  await killHardhatNode(8545, MAINNET_CHAIN_ID);
});

export const executeMessageBatch = task(
  'fork:execute-message-batch',
  'Execute a batch of messages from Ethereum on Arbitrum',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Execute a batch of messages from Ethereum on Arbitrum...');

  const {
    ethers: {
      getContract,
      getContractAt,
      utils: { formatBytes32String, Interface },
    },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  info(`Dispatcher is: ${deployer}`);

  const messageDispatcherArbitrumAddress = await getContractAddress(
    'MessageDispatcherArbitrum',
    MAINNET_CHAIN_ID,
  );

  const greeterAddress = await getContractAddress('Greeter', ARBITRUM_CHAIN_ID);

  const greeter = (await getContractAt(GreeterArtifact.abi, greeterAddress)) as Greeter;

  const greeting = 'Hello from L1';
  const messageData = new Interface(['function setGreeting(string)']).encodeFunctionData(
    'setGreeting',
    [greeting],
  );

  const messages = [
    {
      to: greeterAddress,
      data: messageData,
    },
  ];

  const messageExecutorArbitrum = (await getContract(
    'MessageExecutorArbitrum',
  )) as MessageExecutorArbitrum;

  info(`Greeting before: ${await greeter.callStatic.greeting()}`);

  await processL1ToL2Tx(
    messageDispatcherArbitrumAddress,
    async (signer: SignerWithAddress) =>
      await messageExecutorArbitrum
        .connect(signer)
        .executeMessageBatch(messages, formatBytes32String(''), MAINNET_CHAIN_ID, deployer),
    hre,
  );

  success('Successfully executed messages from Ethereum on Arbitrum!');
  info(`Greeting after: ${await greeter.callStatic.greeting()}`);

  await killHardhatNode(8546, ARBITRUM_CHAIN_ID);
});
