import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import {
  MAINNET_CHAIN_ID,
  ARBITRUM_CHAIN_ID,
  ETH_HOLDER_ADDRESS_MAINNET,
  USDC_HOLDER_ADDRESS_MAINNET,
  ETH_HOLDER_ADDRESS_ARBITRUM,
  USDC_HOLDER_ADDRESS_ARBITRUM,
} from '../../Constants';

import { action, success } from '../../helpers/log';
import { getChainName } from '../../helpers/getChain';

export default task('fork:impersonate', 'Impersonate accounts').setAction(
  async (taskArguments, hre: HardhatRuntimeEnvironment) => {
    const chainId = Number(process.env.CHAIN_ID);

    action(`Impersonate accounts on ${getChainName(chainId)}...`);

    const {
      network: { provider },
    } = hre;

    if (chainId === MAINNET_CHAIN_ID) {
      await provider.request({
        method: 'hardhat_impersonateAccount',
        params: [ETH_HOLDER_ADDRESS_MAINNET],
      });

      await provider.request({
        method: 'hardhat_impersonateAccount',
        params: [USDC_HOLDER_ADDRESS_MAINNET],
      });
    } else if (chainId === ARBITRUM_CHAIN_ID) {
      await provider.request({
        method: 'hardhat_impersonateAccount',
        params: [ETH_HOLDER_ADDRESS_ARBITRUM],
      });

      await provider.request({
        method: 'hardhat_impersonateAccount',
        params: [USDC_HOLDER_ADDRESS_ARBITRUM],
      });
    }

    success('Done!');
  },
);
