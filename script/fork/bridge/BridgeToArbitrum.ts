import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { L1TransactionReceipt, L1ToL2MessageGasEstimator } from '@arbitrum/sdk/';
import { hexDataLength } from '@ethersproject/bytes';
import { BigNumber, providers } from 'ethers';
import kill from 'kill-port';

import { ARBITRUM_CHAIN_ID, MAINNET_CHAIN_ID } from '../../../Constants';
import { getContractAddress } from '../../../helpers/getContract';
import { getChainName } from '../../../helpers/getChain';
import { action, error as errorLog, info, success } from '../../../helpers/log';
import { CrossChainRelayerArbitrum, CrossChainExecutorArbitrum } from '../../../types';

const killHardhatNode = async (port: number, chainId: number) => {
  await kill(port, 'tcp')
    .then(() => success(`Killed ${getChainName(chainId)} Hardhat node`))
    .catch((error) => {
      errorLog(`Failed to kill ${getChainName(chainId)} Hardhat node`);
      console.log(error);
    });
};

export const relayCalls = task(
  'fork:relay-calls',
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

  const crossChainRelayerArbitrum = (await getContract(
    'CrossChainRelayerArbitrum',
  )) as CrossChainRelayerArbitrum;

  const crossChainExecutorAddress = await getContractAddress(
    'CrossChainExecutorArbitrum',
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
      target: greeterAddress,
      data: callData,
    },
  ];

  const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(l2Provider);

  const maxGas = await l1ToL2MessageGasEstimate.estimateRetryableTicketGasLimit({
    from: crossChainRelayerArbitrum.address,
    to: crossChainExecutorAddress,
    l2CallValue: BigNumber.from(0),
    excessFeeRefundAddress: deployer,
    callValueRefundAddress: deployer,
    data: callData,
  });

  await crossChainRelayerArbitrum.relayCalls(calls, maxGas);

  success('Successfully relayed calls from Mainnet to Arbitrum!');

  action('Process calls from Ethereum to Arbitrum...');

  const greetingBytes = defaultAbiCoder.encode(['string'], [greeting]);
  const greetingBytesLength = hexDataLength(greetingBytes) + 4; // 4 bytes func identifier

  const submissionPriceWei = await l1ToL2MessageGasEstimate.estimateSubmissionFee(
    l1Provider,
    await l1Provider.getGasPrice(),
    greetingBytesLength,
  );

  info(`Current retryable base submission price: ${submissionPriceWei.toString()}`);

  const maxSubmissionCost = submissionPriceWei.mul(5);
  const gasPriceBid = await l2Provider.getGasPrice();

  info(`L2 gas price: ${gasPriceBid.toString()}`);

  const callValue = maxSubmissionCost.add(gasPriceBid.mul(maxGas));

  const processCallsTransaction = await crossChainRelayerArbitrum.processCalls(
    1,
    maxSubmissionCost,
    gasPriceBid,
    {
      value: callValue,
    },
  );

  const processCallsTransactionReceipt = await processCallsTransaction.wait();

  const processedCallsEventInterface = new Interface([
    'event ProcessedCalls(address indexed sender, uint256 indexed nonce, uint256 indexed ticketId)',
  ]);

  const processedCallsEventLogs = processedCallsEventInterface.parseLog(
    processCallsTransactionReceipt.logs[2],
  );

  const [sender, nonce, ticketId] = processedCallsEventLogs.args;

  const receipt = await l1Provider.getTransactionReceipt(processCallsTransaction.hash);
  const l1Receipt = new L1TransactionReceipt(receipt);

  const { retryableCreationId }: { retryableCreationId: string } = (
    await l1Receipt.getL1ToL2Messages(l2Provider)
  )[0];

  success('Successfully processed calls from Mainnet to Arbitrum!');
  info(`Sender: ${sender}`);
  info(`Nonce: ${nonce.toString()}`);
  info(`TicketId: ${ticketId.toString()}`);
  info(`RetryableCreationId: ${retryableCreationId}`);

  await killHardhatNode(8545, MAINNET_CHAIN_ID);
});
