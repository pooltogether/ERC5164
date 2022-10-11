/**
 * Helpers are retrieved from the following Arbitrum repository:
 * https://github.com/OffchainLabs/token-bridge-contracts/blob/main/test/testhelper.ts
 */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ContractTransaction } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const applyAlias = (address: string) =>
  '0x' +
  BigInt.asUintN(160, BigInt(address) + BigInt('0x1111000000000000000000000000000000001111'))
    .toString(16)
    .padStart(40, '0');

export const processL1ToL2Tx = async (
  from: string,
  call: (signer: SignerWithAddress) => Promise<ContractTransaction>,
  hre: HardhatRuntimeEnvironment,
) => {
  const {
    ethers: { getSigner },
    network: { provider },
  } = hre;

  const fromAliased = applyAlias(from);

  return provider
    .request({
      // Fund fromAliased to send transaction
      method: 'hardhat_setBalance',
      params: [fromAliased, '0xffffffffffffffffffff'],
    })
    .then(() =>
      provider.request({
        method: 'hardhat_impersonateAccount',
        params: [fromAliased],
      }),
    )
    .then(() => getSigner(fromAliased))
    .then(async (signer) => await call(signer));
};
