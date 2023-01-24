// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { MessageDispatcherOptimism } from "../../src/ethereum-optimism/EthereumToOptimismDispatcher.sol";
import { MessageExecutorOptimism } from "../../src/ethereum-optimism/EthereumToOptimismExecutor.sol";

contract DeployMessageDispatcherToEthereumMainnet is Script {
  address public proxyOVML1CrossDomainMessenger = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;

  function run() public {
    vm.broadcast();

    new MessageDispatcherOptimism(ICrossDomainMessenger(proxyOVML1CrossDomainMessenger), 10);

    vm.stopBroadcast();
  }
}

contract DeployMessageExecutorToOptimism is Script {
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;

  function run() public {
    vm.broadcast();

    new MessageExecutorOptimism(ICrossDomainMessenger(l2CrossDomainMessenger));

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetMessageExecutor is DeployedContracts {
  function setMessageExecutor() public {
    MessageDispatcherOptimism _messageDispatcher = _getMessageDispatcherOptimism();
    MessageExecutorOptimism _messageExecutor = _getMessageExecutorOptimism();

    _messageDispatcher.setExecutor(_messageExecutor);
  }

  function run() public {
    vm.broadcast();

    setMessageExecutor();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetMessageDispatcher is DeployedContracts {
  function setMessageDispatcher() public {
    MessageDispatcherOptimism _messageDispatcher = _getMessageDispatcherOptimism();
    MessageExecutorOptimism _messageExecutor = _getMessageExecutorOptimism();

    _messageExecutor.setDispatcher(_messageDispatcher);
  }

  function run() public {
    vm.broadcast();

    setMessageDispatcher();

    vm.stopBroadcast();
  }
}
