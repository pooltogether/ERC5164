import { L1TransactionReceipt, L1ToL2MessageGasEstimator } from '@arbitrum/sdk/';
import { getBaseFee } from '@arbitrum/sdk/dist/lib/utils/lib';
import { BigNumber, providers } from 'ethers';
import hre from 'hardhat';

import { ARBITRUM_GOERLI_CHAIN_ID, GOERLI_CHAIN_ID } from '../../Constants';
import { getContractAddress } from '../../helpers/getContract';
import { action, error as errorLog, info, success } from '../../helpers/log';
import { MessageDispatcherArbitrum } from '../../types';
import MessageDispatcherArbitrumArtifact from '../../out/EthereumToArbitrumDispatcher.sol/MessageDispatcherArbitrum.json';

const main = async () => {
  action('Dispatch message from Ethereum to Arbitrum...');

  const {
    ethers: {
      getContractAt,
      provider: l1Provider,
      utils: { Interface },
    },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  const l2Provider = new providers.JsonRpcProvider(process.env.ARBITRUM_GOERLI_RPC_URL);

  info(`Dispatcher is: ${deployer}`);

  const messageDispatcherArbitrumAddress = await getContractAddress(
    'MessageDispatcherArbitrum',
    GOERLI_CHAIN_ID,
    'Forge',
  );

  const messageDispatcherArbitrum = (await getContractAt(
    MessageDispatcherArbitrumArtifact.abi,
    messageDispatcherArbitrumAddress,
  )) as MessageDispatcherArbitrum;

  const messageExecutorAddress = await getContractAddress(
    'MessageExecutorArbitrum',
    ARBITRUM_GOERLI_CHAIN_ID,
    'Forge',
  );

  const greeterAddress = await getContractAddress('Greeter', ARBITRUM_GOERLI_CHAIN_ID, 'Forge');

  const greeting = 'Hello from L1';
  const messageData = new Interface(['function setGreeting(string)']).encodeFunctionData(
    'setGreeting',
    [greeting],
  );

  const dispatchMessageTransaction = await messageDispatcherArbitrum.dispatchMessage(
    ARBITRUM_GOERLI_CHAIN_ID,
    greeterAddress,
    messageData,
  );
  const dispatchMessageTransactionReceipt = await dispatchMessageTransaction.wait();

  const dispatchedMessagesEventInterface = new Interface([
    'event MessageDispatched(bytes32 indexed messageId, address indexed from, uint256 indexed toChainId, address to, bytes data)',
  ]);

  const dispatchedMessagesEventLogs = dispatchedMessagesEventInterface.parseLog(
    dispatchMessageTransactionReceipt.logs[0],
  );

  const [messageId] = dispatchedMessagesEventLogs.args;

  success('Successfully dispatched message from Ethereum to Arbitrum!');
  info(`MessageId: ${messageId}`);

  const executeMessageData = new Interface([
    'function executeMessage(address,bytes,bytes32,uint256,address)',
  ]).encodeFunctionData('executeMessage', [
    greeterAddress,
    messageData,
    messageId,
    GOERLI_CHAIN_ID,
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

  info(`Current retryable base submission price is: ${maxSubmissionCost.toString()}`);

  action('Process message from Ethereum to Arbitrum...');

  const gasPriceBid = await l2Provider.getGasPrice();

  info(`L2 gas price: ${gasPriceBid.toString()}`);

  info(`Sending greeting to L2 with ${deposit.toString()} messageValue for L2 fees:`);

  const processMessageTransaction = await messageDispatcherArbitrum.processMessage(
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

  const processMessageTransactionReceipt = await processMessageTransaction.wait();

  const messageProcessedEventInterface = new Interface([
    'event MessageProcessed(bytes32 indexed messageId, address indexed sender, uint256 indexed ticketId)',
  ]);

  const messageProcessedEventLogs = messageProcessedEventInterface.parseLog(
    processMessageTransactionReceipt.logs[2],
  );

  const [processedMessageId, sender, ticketId] = messageProcessedEventLogs.args;

  const receipt = await l1Provider.getTransactionReceipt(processMessageTransaction.hash);
  const l1Receipt = new L1TransactionReceipt(receipt);

  const { retryableCreationId }: { retryableCreationId: string } = (
    await l1Receipt.getL1ToL2Messages(l2Provider)
  )[0];

  success('Successfully processed message from Ethereum to Arbitrum!');
  info(`MessageId: ${processedMessageId.toString()}`);
  info(`Sender: ${sender}`);
  info(`TicketId: ${ticketId.toString()}`);
  info(`RetryableCreationId: ${retryableCreationId}`);
};

main().catch((error) => {
  errorLog('Failed to bridge to Arbitrum Goerli');
  console.error(error);
  process.exitCode = 1;
});
