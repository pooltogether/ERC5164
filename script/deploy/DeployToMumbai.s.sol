// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { MessageExecutorPolygon } from "../../src/ethereum-polygon/EthereumToPolygonExecutor.sol";
import { MessageDispatcherPolygon } from "../../src/ethereum-polygon/EthereumToPolygonDispatcher.sol";

import { Greeter } from "../../test/contracts/Greeter.sol";

contract DeployMessageDispatcherToGoerli is Script {
  address public checkpointManager = 0x2890bA17EfE978480615e330ecB65333b880928e;
  address public fxRoot = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;

  function run() public {
    vm.broadcast();

    new MessageDispatcherPolygon(checkpointManager, fxRoot, 80001);

    vm.stopBroadcast();
  }
}

contract DeployMessageExecutorToMumbai is Script {
  address public fxChild = 0xCf73231F28B7331BBe3124B907840A94851f9f11;

  function run() public {
    vm.broadcast();

    new MessageExecutorPolygon(fxChild);

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetFxChildTunnel is DeployedContracts {
  function setFxChildTunnel() public {
    MessageDispatcherPolygon _messageDispatcher = _getMessageDispatcherPolygon();
    MessageExecutorPolygon _messageExecutor = _getMessageExecutorPolygon();

    _messageDispatcher.setFxChildTunnel(address(_messageExecutor));
  }

  function run() public {
    vm.broadcast();

    setFxChildTunnel();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetFxRootTunnel is DeployedContracts {
  function setFxRootTunnel() public {
    MessageDispatcherPolygon _messageDispatcher = _getMessageDispatcherPolygon();
    MessageExecutorPolygon _messageExecutor = _getMessageExecutorPolygon();

    _messageExecutor.setFxRootTunnel(address(_messageDispatcher));
  }

  function run() public {
    vm.broadcast();

    setFxRootTunnel();

    vm.stopBroadcast();
  }
}

contract DeployGreeterToMumbai is DeployedContracts {
  function run() public {
    vm.broadcast();

    MessageExecutorPolygon _messageExecutor = _getMessageExecutorPolygon();
    new Greeter(address(_messageExecutor), "Hello from L2");

    vm.stopBroadcast();
  }
}
