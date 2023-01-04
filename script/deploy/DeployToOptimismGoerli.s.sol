// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { MessageExecutorOptimism } from "../../src/ethereum-optimism/EthereumToOptimismExecutor.sol";
import { MessageDispatcherOptimism } from "../../src/ethereum-optimism/EthereumToOptimismDispatcher.sol";
import { Greeter } from "../../test/contracts/Greeter.sol";

contract DeployMessageDispatcherToGoerli is Script {
  address public proxyOVML1CrossDomainMessenger = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;

  function run() public {
    vm.broadcast();

    new MessageDispatcherOptimism(ICrossDomainMessenger(proxyOVML1CrossDomainMessenger), 420);

    vm.stopBroadcast();
  }
}

contract DeployMessageExecutorToOptimismGoerli is Script {
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

contract DeployGreeterToOptimismGoerli is DeployedContracts {
  function deployGreeter() public {
    MessageExecutorOptimism _messageExecutor = _getMessageExecutorOptimism();
    new Greeter(address(_messageExecutor), "Hello from L2");
  }

  function run() public {
    vm.broadcast();

    deployGreeter();

    vm.stopBroadcast();
  }
}
