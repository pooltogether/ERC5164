import { MAINNET_CHAIN_ID, ARBITRUM_CHAIN_ID } from '../Constants';

const chainName: { [key: number]: string } = {
  [MAINNET_CHAIN_ID]: 'Ethereum Mainnet',
  [ARBITRUM_CHAIN_ID]: 'Arbitrum Mainnet',
};

export const getChainName = (chainId: number) => {
  return chainName[chainId];
};
