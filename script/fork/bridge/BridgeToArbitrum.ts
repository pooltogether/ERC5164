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

export const dispatchMessages = task(
  'fork:dispatch-message',
  'Relay calls from Ethereum to Arbitrum',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Relay calls from Ethereum to Arbitrum...');

  const {
    ethers: {
      getContract,
      provider: l1Provider,
      utils: { defaultAbiCoder, Interface },
    },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  const l2Provider = new providers.JsonRpcProvider(process.env.ARBITRUM_RPC_URL);

  info(`Caller is: ${deployer}`);

  const messageDispatcherArbitrum = (await getContract(
    'MessageDispatcherArbitrum',
  )) as MessageDispatcherArbitrum;

  const messageExecutorAddress = await getContractAddress(
    'MessageExecutorArbitrum',
    ARBITRUM_CHAIN_ID,
  );

  const greeterAddress = await getContractAddress('Greeter', ARBITRUM_CHAIN_ID);

  const greeting = 'Hello from L1';
  const callData = new Interface(['function setGreeting(string)']).encodeFunctionData(
    'setGreeting',
    [greeting],
  );

  const calls = [
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
      from: messageDispatcherArbitrum.address,
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
  info(`Sender: ${from}`);
  info(`Nonce: ${nonce.toString()}`);
  info(`TicketId: ${ticketId.toString()}`);
  info(`RetryableCreationId: ${retryableCreationId}`);

  await killHardhatNode(8545, MAINNET_CHAIN_ID);
});

export const executeCalls = task(
  'fork:execute-calls',
  'Execute calls from Ethereum on Arbitrum',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Execute calls from Ethereum on Arbitrum...');

  const {
    ethers: {
      getContract,
      getContractAt,
      utils: { Interface },
    },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  info(`Caller is: ${deployer}`);

  const messageDispatcherArbitrumAddress = await getContractAddress(
    'MessageDispatcherArbitrum',
    MAINNET_CHAIN_ID,
  );

  const greeterAddress = await getContractAddress('Greeter', ARBITRUM_CHAIN_ID);

  const greeter = (await getContractAt(GreeterArtifact.abi, greeterAddress)) as Greeter;

  const greeting = 'Hello from L1';
  const callData = new Interface(['function setGreeting(string)']).encodeFunctionData(
    'setGreeting',
    [greeting],
  );

  const calls = [
    {
      to: greeterAddress,
      data: callData,
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
        .executeCalls(calls, BigNumber.from(1), deployer, MAINNET_CHAIN_ID),
    hre,
  );

  success('Successfully executed calls from Ethereum on Arbitrum!');
  info(`Greeting after: ${await greeter.callStatic.greeting()}`);

  await killHardhatNode(8546, ARBITRUM_CHAIN_ID);
});
