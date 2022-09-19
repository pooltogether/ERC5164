// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";

import "../../src/executors/CrossChainExecutorPolygon.sol";
import "../../test/Greeter.sol";

contract DeployPolygonExecutorToMumbai is Script {
  address public fxChild = 0xCf73231F28B7331BBe3124B907840A94851f9f11;

  function run() public {
    vm.broadcast();

    CrossChainExecutorPolygon crossChainExecutorMumbai = new CrossChainExecutorPolygon(fxChild);

    vm.stopBroadcast();

    vm.broadcast();

    new Greeter(address(crossChainExecutorMumbai), "Hello from L2");

    vm.stopBroadcast();
  }
}

contract DeployPolygonRelayerToGoerli is Script {
  address public checkpointManager = 0x2890bA17EfE978480615e330ecB65333b880928e;
  address public fxRoot = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;

  function run() public {
    vm.broadcast();

    new CrossChainRelayerPolygon(checkpointManager, fxRoot, 30000000);

    vm.stopBroadcast();
  }
}
