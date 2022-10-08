import { Contract } from 'ethers';
import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { error as errorLog } from './log';
import {
  MAINNET_CHAIN_ID,
  ARBITRUM_CHAIN_ID,
  GOERLI_CHAIN_ID,
  ARBITRUM_GOERLI_CHAIN_ID,
} from '../Constants';

const deploymentFolderPathHardhat: { [key: number]: string } = {
  [MAINNET_CHAIN_ID]: 'deployments/localhostMainnet',
  [ARBITRUM_CHAIN_ID]: 'deployments/localhostArbitrum',
};

const deploymentFolderPathForge: { [key: number]: string } = {
  [GOERLI_CHAIN_ID]: 'broadcast/DeployToArbitrumGoerli.s.sol/5',
  [ARBITRUM_GOERLI_CHAIN_ID]: 'broadcast/DeployToArbitrumGoerli.s.sol/421613',
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
  deployer: 'Hardhat' | 'Forge' = 'Hardhat',
): Promise<string> => {
  let address = '';

  const deploymentFolderPath =
    deployer === 'Hardhat' ? deploymentFolderPathHardhat : deploymentFolderPathForge;

  const deploymentPath = `${__dirname.slice(0, __dirname.lastIndexOf('/'))}/${
    deploymentFolderPath[chainId]
  }`;

  await fs.promises
    .readdir(deploymentPath, { withFileTypes: true })
    .then(async (files) => {
      files.reverse();

      for (const file of files) {
        if (deployer === 'Hardhat') {
          if (file.name.startsWith(contractName)) {
            const filePath = `${deploymentPath}/${file.name}`;

            await fs.promises.readFile(filePath).then((content) => {
              const data = JSON.parse(content.toString());

              address = data.address;
            });
          }
        } else {
          const filePath = `${deploymentPath}/${file.name}`;

          await fs.promises.readFile(filePath).then((content) => {
            const data = JSON.parse(content.toString());

            if (data.transactions[0].contractName === contractName) {
              address = data.transactions[0].contractAddress;
            }
          });

          if (address !== '') {
            break;
          }
        }
      }
    })
    .catch((error) => {
      errorLog(`Failed to retrieve ${contractName} address.`);
      console.log(error);
    });

  return address;
};
