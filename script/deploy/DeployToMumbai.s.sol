// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { CrossChainExecutorPolygon } from "../../src/ethereum-polygon/EthereumToPolygonExecutor.sol";
import { CrossChainRelayerPolygon } from "../../src/ethereum-polygon/EthereumToPolygonRelayer.sol";

import { Greeter } from "../../test/contracts/Greeter.sol";

contract DeployCrossChainRelayerToGoerli is Script {
  address public checkpointManager = 0x2890bA17EfE978480615e330ecB65333b880928e;
  address public fxRoot = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;

  function run() public {
    vm.broadcast();

    new CrossChainRelayerPolygon(checkpointManager, fxRoot);

    vm.stopBroadcast();
  }
}

contract DeployCrossChainExecutorToMumbai is Script {
  address public fxChild = 0xCf73231F28B7331BBe3124B907840A94851f9f11;

  function run() public {
    vm.broadcast();

    new CrossChainExecutorPolygon(fxChild);

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying CrossChainRelayer and CrossChainExecutor
contract SetFxChildTunnel is DeployedContracts {
  function setFxChildTunnel() public {
    CrossChainRelayerPolygon _crossChainRelayer = _getCrossChainRelayerPolygon();
    CrossChainExecutorPolygon _crossChainExecutor = _getCrossChainExecutorPolygon();

    _crossChainRelayer.setFxChildTunnel(address(_crossChainExecutor));
  }

  function run() public {
    vm.broadcast();

    setFxChildTunnel();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying CrossChainRelayer and CrossChainExecutor
contract SetFxRootTunnel is DeployedContracts {
  function setFxRootTunnel() public {
    CrossChainRelayerPolygon _crossChainRelayer = _getCrossChainRelayerPolygon();
    CrossChainExecutorPolygon _crossChainExecutor = _getCrossChainExecutorPolygon();

    _crossChainExecutor.setFxRootTunnel(address(_crossChainRelayer));
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

    CrossChainExecutorPolygon _crossChainExecutor = _getCrossChainExecutorPolygon();
    new Greeter(address(_crossChainExecutor), "Hello from L2");

    vm.stopBroadcast();
  }
}
