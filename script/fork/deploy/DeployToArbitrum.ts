import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { ARBITRUM_CHAIN_ID, MAINNET_CHAIN_ID, DELAYED_INBOX } from '../../../Constants';
import { getContractAddress } from '../../../helpers/getContract';
import { action, info, success } from '../../../helpers/log';
import { MessageDispatcherArbitrum, MessageExecutorArbitrum } from '../../../types';

export const deployDispatcher = task(
  'fork:deploy-dispatcher',
  'Deploy Arbitrum Dispatcher on Ethereum',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Deploy Dispatcher on Ethereum...');

  const {
    deployments: { deploy },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  info(`Deployer is: ${deployer}`);

  const { address } = await deploy('MessageDispatcherArbitrum', {
    from: deployer,
    args: [DELAYED_INBOX, ARBITRUM_CHAIN_ID],
  });

  success(`Arbitrum Dispatcher deployed on Ethereum at address: ${address}`);
});

export const deployExecutor = task(
  'fork:deploy-executor',
  'Deploy Arbitrum Executor on Arbitrum',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Deploy Executor on Arbitrum...');

  const {
    deployments: { deploy },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  info(`Deployer is: ${deployer}`);

  const { address } = await deploy('MessageExecutorArbitrum', {
    from: deployer,
  });

  success(`Arbitrum Executor deployed on Arbitrum at address: ${address}`);
});

export const deployGreeter = task('fork:deploy-greeter', 'Deploy Greeter on Arbitrum').setAction(
  async (taskArguments, hre: HardhatRuntimeEnvironment) => {
    action('Deploy Greeter on Arbitrum...');

    const {
      deployments: { deploy },
      getNamedAccounts,
    } = hre;

    const { deployer } = await getNamedAccounts();

    info(`Deployer is: ${deployer}`);

    const messageExecutorArbitrumAddress = await getContractAddress(
      'MessageExecutorArbitrum',
      ARBITRUM_CHAIN_ID,
    );

    const { address } = await deploy('Greeter', {
      from: deployer,
      args: [messageExecutorArbitrumAddress, 'Hello from L2'],
    });

    success(`Arbitrum Greeter deployed on Arbitrum at address: ${address}`);
  },
);

export const setExecutor = task(
  'fork:set-executor',
  'Set Executor on Arbitrum Dispatcher',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Set Executor on Arbitrum Dispatcher...');

  const messageDispatcherArbitrum = (await hre.ethers.getContract(
    'MessageDispatcherArbitrum',
  )) as MessageDispatcherArbitrum;

  const messageExecutorArbitrumAddress = await getContractAddress(
    'MessageExecutorArbitrum',
    ARBITRUM_CHAIN_ID,
  );

  await messageDispatcherArbitrum.setExecutor(messageExecutorArbitrumAddress);

  success('Executor set on Arbitrum Dispatcher!');
});

export const setDispatcher = task(
  'fork:set-dispatcher',
  'Set Dispatcher on Arbitrum Executor',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Set Dispatcher on Arbitrum Executor...');

  const messageExecutorArbitrum = (await hre.ethers.getContract(
    'MessageExecutorArbitrum',
  )) as MessageExecutorArbitrum;

  const messageDispatcherArbitrumAddress = await getContractAddress(
    'MessageDispatcherArbitrum',
    MAINNET_CHAIN_ID,
  );

  await messageExecutorArbitrum.setDispatcher(messageDispatcherArbitrumAddress);

  success('Dispatcher set on Arbitrum Executor!');
});
