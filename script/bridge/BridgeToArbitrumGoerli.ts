import { L1TransactionReceipt, L1ToL2MessageGasEstimator } from '@arbitrum/sdk/';
import { getBaseFee } from '@arbitrum/sdk/dist/lib/utils/lib';
import { BigNumber, providers } from 'ethers';
import hre from 'hardhat';

import { ARBITRUM_GOERLI_CHAIN_ID, GOERLI_CHAIN_ID } from '../../Constants';
import { getContractAddress } from '../../helpers/getContract';
import { action, error as errorLog, info, success } from '../../helpers/log';
import { MessageDispatcherArbitrum } from '../../types';
import { CallLib } from '../../types/IMessageDispatcher';
import MessageDispatcherArbitrumArtifact from '../../out/EthereumToArbitrumDispatcher.sol/MessageDispatcherArbitrum.json';

const main = async () => {
  action('Relay calls from Ethereum to Arbitrum...');

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

  info(`Caller is: ${deployer}`);

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
  const callData = new Interface(['function setGreeting(string)']).encodeFunctionData(
    'setGreeting',
    [greeting],
  );

  const calls: CallLib.CallStruct[] = [
    {
      to: greeterAddress,
      data: callData,
    },
  ];

  const nextNonce = (await messageDispatcherArbitrum.nonce()).add(1);

  const executeCallsData = new Interface([
    'function executeCalls(uint256,address,(address,bytes)[])',
  ]).encodeFunctionData('executeCalls', [nextNonce, deployer, [[greeterAddress, callData]]]);

  const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(l2Provider);
  const baseFee = await getBaseFee(l1Provider);

  /**
   * The estimateAll method gives us the following values for sending an L1->L2 message
   * (1) maxSubmissionCost: The maximum cost to be paid for submitting the transaction
   * (2) gasLimit: The L2 gas limit
   * (3) deposit: The total amount to deposit on L1 to cover L2 gas and L2 call value
   */
  const { deposit, gasLimit, maxSubmissionCost } = await l1ToL2MessageGasEstimate.estimateAll(
    {
      from: messageDispatcherArbitrumAddress,
      to: messageExecutorAddress,
      l2CallValue: BigNumber.from(0),
      excessFeeRefundAddress: deployer,
      callValueRefundAddress: deployer,
      data: executeCallsData,
    },
    baseFee,
    l1Provider,
  );

  info(`Current retryable base submission price is: ${maxSubmissionCost.toString()}`);

  const dispatchMessagesTransaction = await messageDispatcherArbitrum.dispatchMessages(calls);
  const dispatchMessagesTransactionReceipt = await dispatchMessagesTransaction.wait();

  const relayedCallsEventInterface = new Interface([
    'event RelayedCalls(uint256 indexed nonce, address indexed from, (address to,bytes data)[], uint256 toChainId)',
  ]);

  const relayedCallsEventLogs = relayedCallsEventInterface.parseLog(
    dispatchMessagesTransactionReceipt.logs[0],
  );

  const [dispatchMessagesNonce] = relayedCallsEventLogs.args;

  success('Successfully relayed calls from Ethereum to Arbitrum!');
  info(`Nonce: ${dispatchMessagesNonce}`);

  action('Process calls from Ethereum to Arbitrum...');

  const gasPriceBid = await l2Provider.getGasPrice();

  info(`L2 gas price: ${gasPriceBid.toString()}`);

  info(`Sending greeting to L2 with ${deposit.toString()} callValue for L2 fees:`);

  const processCallsTransaction = await messageDispatcherArbitrum.processCalls(
    dispatchMessagesNonce,
    calls,
    deployer,
    deployer,
    gasLimit,
    maxSubmissionCost,
    gasPriceBid,
    {
      value: deposit,
    },
  );

  const processCallsTransactionReceipt = await processCallsTransaction.wait();

  const processedCallsEventInterface = new Interface([
    'event ProcessedCalls(uint256 indexed nonce, address indexed from, uint256 indexed ticketId)',
  ]);

  const processedCallsEventLogs = processedCallsEventInterface.parseLog(
    processCallsTransactionReceipt.logs[2],
  );

  const [nonce, from, ticketId] = processedCallsEventLogs.args;

  const receipt = await l1Provider.getTransactionReceipt(processCallsTransaction.hash);
  const l1Receipt = new L1TransactionReceipt(receipt);

  const { retryableCreationId }: { retryableCreationId: string } = (
    await l1Receipt.getL1ToL2Messages(l2Provider)
  )[0];

  success('Successfully processed calls from Ethereum to Arbitrum!');
  info(`Nonce: ${nonce.toString()}`);
  info(`Sender: ${from}`);
  info(`TicketId: ${ticketId.toString()}`);
  info(`RetryableCreationId: ${retryableCreationId}`);
};

main().catch((error) => {
  errorLog('Failed to bridge to Arbitrum Goerli');
  console.error(error);
  process.exitCode = 1;
});
