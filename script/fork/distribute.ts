import { task } from 'hardhat/config';

import ERC20 from '../../abis/ERC20.json';

import {
  MAINNET_CHAIN_ID,
  ARBITRUM_CHAIN_ID,
  USDC_ADDRESS_MAINNET,
  USDC_ADDRESS_ARBITRUM,
  USDC_TOKEN_DECIMALS,
  ETH_HOLDER_ADDRESS_MAINNET,
  USDC_HOLDER_ADDRESS_MAINNET,
  ETH_HOLDER_ADDRESS_ARBITRUM,
  USDC_HOLDER_ADDRESS_ARBITRUM,
} from '../../Constants';

import { action, success } from '../../helpers/log';
import { getChainName } from '../../helpers/getChain';

type KeyMapping = { [key: number]: string };

const getETHHolderAddress = (chainId: number) => {
  const ethHolderAddress: KeyMapping = {
    [MAINNET_CHAIN_ID]: ETH_HOLDER_ADDRESS_MAINNET,
    [ARBITRUM_CHAIN_ID]: ETH_HOLDER_ADDRESS_ARBITRUM,
  };

  return ethHolderAddress[chainId];
};

const getUSDCHolderAddress = (chainId: number) => {
  const usdcHolderAddress: KeyMapping = {
    [MAINNET_CHAIN_ID]: USDC_HOLDER_ADDRESS_MAINNET,
    [ARBITRUM_CHAIN_ID]: USDC_HOLDER_ADDRESS_ARBITRUM,
  };

  return usdcHolderAddress[chainId];
};

const getUSDCContractAddress = (chainId: number) => {
  const usdcContractAddress: KeyMapping = {
    [MAINNET_CHAIN_ID]: USDC_ADDRESS_MAINNET,
    [ARBITRUM_CHAIN_ID]: USDC_ADDRESS_ARBITRUM,
  };

  return usdcContractAddress[chainId];
};

export default task('fork:distribute', 'Distribute Ether and USDC').setAction(
  async (taskArguments, hre) => {
    const {
      ethers,
      network: {
        config: { chainId },
      },
    } = hre;
    const { provider, getContractAt, getSigners } = ethers;
    const [deployer, wallet2] = await getSigners();

    if (chainId) {
      action(`Distributing Ether and USDC on ${getChainName(chainId)}...`);

      const ethHolder = provider.getUncheckedSigner(getETHHolderAddress(chainId));
      const usdcHolder = provider.getUncheckedSigner(getUSDCHolderAddress(chainId));
      const usdcContract = await getContractAt(ERC20, getUSDCContractAddress(chainId), usdcHolder);

      const recipients: { [key: string]: string } = {
        ['Deployer']: deployer.address,
        ['Wallet 2']: wallet2.address,
      };

      const keys = Object.keys(recipients);

      for (var i = 0; i < keys.length; i++) {
        const name = keys[i];
        const address = recipients[name];

        action(`Sending 1000 ETH to ${name}...`);
        await ethHolder.sendTransaction({
          to: address,
          value: ethers.utils.parseEther('1000'),
        });

        action(`Sending 1000 USDC to ${name}...`);
        await usdcContract.transfer(address, ethers.utils.parseUnits('1000', USDC_TOKEN_DECIMALS));
      }

      success('Done!');
    }
  },
);
