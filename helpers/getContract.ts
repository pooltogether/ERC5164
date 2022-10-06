import { Contract } from 'ethers';
import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { error as errorLog } from './log';
import { MAINNET_CHAIN_ID, ARBITRUM_CHAIN_ID } from '../Constants';

const deploymentFolderPath: { [key: number]: string } = {
  [MAINNET_CHAIN_ID]: 'deployments/localhostMainnet',
  [ARBITRUM_CHAIN_ID]: 'deployments/localhostArbitrum',
};

/**
 * Temporary helper until the following incompatibility with hardhat-toolbox is fixed
 * https://github.com/NomicFoundation/hardhat/issues/1040
 */
export const getContract = async (
  contractName: string,
  hre: HardhatRuntimeEnvironment,
): Promise<void | Contract> => {
  const {
    deployments: { getOrNull },
    ethers: { getContractAt },
  } = hre;

  const contract = await getOrNull(contractName);

  if (contract) {
    return await getContractAt(contractName, contract.address);
  } else {
    errorLog(`Failed to retrieve ${contractName} contract.`);
  }
};

export const getContractAddress = async (
  contractName: string,
  chainId: number,
): Promise<string> => {
  let address = '';

  const deploymentPath = `${__dirname.slice(0, __dirname.lastIndexOf('/'))}/${
    deploymentFolderPath[chainId]
  }`;

  await fs.promises
    .readdir(deploymentPath, { withFileTypes: true })
    .then(async (files) => {
      let filePath;

      for (const file of files) {
        if (file.name.startsWith(contractName)) {
          const filePath = `${deploymentPath}/${contractName}.json`;

          await fs.promises.readFile(filePath).then((content) => {
            const data = JSON.parse(content.toString());

            address = data.address;
          });
        }
      }
    })
    .catch((error) => {
      errorLog(`Failed to retrieve ${contractName} address.`);
      console.log(error);
    });

  return address;
};
