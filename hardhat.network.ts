import { HardhatUserConfig } from 'hardhat/config';

import {
  MAINNET_CHAIN_ID,
  ARBITRUM_CHAIN_ID,
  OPTIMISM_CHAIN_ID,
  POLYGON_CHAIN_ID,
  GOERLI_CHAIN_ID,
} from './Constants';

const mainnetRPCUrl = process.env.MAINNET_RPC_URL;
const arbitrumRPCUrl = process.env.ARBITRUM_RPC_URL;
const optimismRPCUrl = process.env.OPTIMISM_RPC_URL;
const polygonRPCUrl = process.env.OPTIMISM_RPC_URL;

const goerliRPCUrl = process.env.GOERLI_RPC_URL;

const mnemonic = process.env.HDWALLET_MNEMONIC;

const chainId = Number(process.env.CHAIN_ID);

const networks: HardhatUserConfig['networks'] = {
  coverage: {
    url: 'http://127.0.0.1:8555',
    blockGasLimit: 200000000,
    allowUnlimitedContractSize: true,
  },
  localhostMainnet: {
    chainId,
    url: 'http://127.0.0.1:8545',
    allowUnlimitedContractSize: true,
  },
  localhostArbitrum: {
    chainId,
    url: 'http://127.0.0.1:8546',
    allowUnlimitedContractSize: true,
  },
};

if (goerliRPCUrl && mnemonic) {
  networks.goerli = {
    chainId: GOERLI_CHAIN_ID,
    url: goerliRPCUrl,
    accounts: {
      mnemonic,
    },
  };
}

if (process.env.FORK_ENABLED && mnemonic) {
  const defaultHardhatConfig = {
    accounts: {
      mnemonic,
    },
    allowUnlimitedContractSize: true,
  };

  if (chainId === MAINNET_CHAIN_ID && mainnetRPCUrl) {
    networks.hardhat = {
      chainId: MAINNET_CHAIN_ID,
      forking: {
        url: mainnetRPCUrl,
        blockNumber: 15684520,
      },
      ...defaultHardhatConfig,
    };
  } else if (chainId === ARBITRUM_CHAIN_ID && arbitrumRPCUrl) {
    networks.hardhat = {
      chainId: ARBITRUM_CHAIN_ID,
      forking: {
        url: arbitrumRPCUrl,
        blockNumber: 28574320,
      },
      ...defaultHardhatConfig,
    };
  } else if (chainId === OPTIMISM_CHAIN_ID && optimismRPCUrl) {
    networks.hardhat = {
      chainId: OPTIMISM_CHAIN_ID,
      forking: {
        url: optimismRPCUrl,
      },
      ...defaultHardhatConfig,
    };
  } else if (chainId === POLYGON_CHAIN_ID && polygonRPCUrl) {
    networks.hardhat = {
      chainId: POLYGON_CHAIN_ID,
      forking: {
        url: polygonRPCUrl,
      },
      ...defaultHardhatConfig,
    };
  }
}

export default networks;
