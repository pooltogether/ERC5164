import * as fs from 'fs';
import glob from 'glob';

import { HardhatUserConfig, subtask } from 'hardhat/config';
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names';

import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-ethers';
import '@typechain/hardhat';
import 'hardhat-deploy';
import 'hardhat-preprocessor';

import * as forkTasks from './script/fork';
import networks from './hardhat.network';

function getRemappings() {
  return fs
    .readFileSync('remappings.txt', 'utf8')
    .split('\n')
    .filter(Boolean) // remove empty lines
    .map((line: string) => line.trim().split('='));
}

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks,
  paths: {
    artifacts: './out',
    sources: './src',
    cache: './cache_hardhat',
    tests: './test',
  },
  preprocess: {
    eachLine: () => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  solidity: {
    version: '0.8.16',
    settings: {
      optimizer: {
        enabled: true,
        runs: 2000,
      },
      viaIR: true,
    },
  },
  typechain: {
    outDir: './types',
    target: 'ethers-v5',
  },
};

subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS, async () => {
  return [...glob.sync('./src/**/*.sol'), ...glob.sync('./test/**/*.sol')];
});

forkTasks;

export default config;
