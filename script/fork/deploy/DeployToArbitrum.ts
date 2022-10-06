import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import {
  ARBITRUM_CHAIN_ID,
  MAINNET_CHAIN_ID,
  DELAYED_INBOX,
  MAX_TX_GAS_LIMIT,
} from '../../../Constants';
import { getContractAddress } from '../../../helpers/getContract';
import { action, info, success } from '../../../helpers/log';
import { CrossChainRelayerArbitrum, CrossChainExecutorArbitrum } from '../../../types';

export const deployRelayer = task(
  'fork:deploy-relayer',
  'Deploy Arbitrum Relayer on Ethereum',
).setAction(async (taskArguments, hre: HardhatRuntimeEnvironment) => {
  action('Deploy Relayer on Ethereum...');

  const {
    deployments: { deploy },
    getNamedAccounts,
  } = hre;

  const { deployer } = await getNamedAccounts();

  info(`Deployer is: ${deployer}`);

  const { address } = await deploy('CrossChainRelayerArbitrum', {
    from: deployer,
    args: [DELAYED_INBOX, MAX_TX_GAS_LIMIT],
  });

  success(`Arbitrum Relayer deployed on Ethereum at address: ${address}`);
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

  const { address } = await deploy('CrossChainExecutorArbitrum', {
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

    const crossChainExecutorArbitrumAddress = await getContractAddress(
      'CrossChainExecutorArbitrum',
      ARBITRUM_CHAIN_ID,
    );

    const { address } = await deploy('Greeter', {
      from: deployer,
      args: [crossChainExecutorArbitrumAddress, 'Hello from L2'],
    });

    success(`Arbitrum Greeter deployed on Arbitrum at address: ${address}`);
  },
);

export const setExecutor = task('fork:set-executor', 'Set Executor on Arbitrum Relayer').setAction(
  async (taskArguments, hre: HardhatRuntimeEnvironment) => {
    action('Set Executor on Arbitrum Relayer...');

    const crossChainRelayerArbitrum = (await hre.ethers.getContract(
      'CrossChainRelayerArbitrum',
    )) as CrossChainRelayerArbitrum;

    const crossChainExecutorArbitrumAddress = await getContractAddress(
      'CrossChainExecutorArbitrum',
      ARBITRUM_CHAIN_ID,
    );

    await crossChainRelayerArbitrum.setExecutor(crossChainExecutorArbitrumAddress);

    success('Executor set on Arbitrum Relayer!');
  },
);

export const setRelayer = task('fork:set-relayer', 'Set Relayer on Arbitrum Executor').setAction(
  async (taskArguments, hre: HardhatRuntimeEnvironment) => {
    action('Set Relayer on Arbitrum Executor...');

    const crossChainExecutorArbitrum = (await hre.ethers.getContract(
      'CrossChainExecutorArbitrum',
    )) as CrossChainExecutorArbitrum;

    const crossChainRelayerArbitrumAddress = await getContractAddress(
      'CrossChainRelayerArbitrum',
      MAINNET_CHAIN_ID,
    );

    await crossChainExecutorArbitrum.setRelayer(crossChainRelayerArbitrumAddress);

    success('Relayer set on Arbitrum Executor!');
  },
);
