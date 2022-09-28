// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";
import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { ICrossChainRelayer } from "../../src/interfaces/ICrossChainRelayer.sol";
import { CrossChainRelayerOptimism } from "../../src/relayers/CrossChainRelayerOptimism.sol";

contract BridgeToOptimismGoerli is DeployedContracts {
  function bridgeToOptimism() public {
    CrossChainRelayerOptimism _crossChainRelayer = _getCrossChainRelayerOptimism();
    address _greeter = address(_getGreeterOptimism());

    ICrossChainRelayer.Call[] memory _calls = new ICrossChainRelayer.Call[](1);

    _calls[0] = ICrossChainRelayer.Call({
      target: _greeter,
      data: abi.encodeWithSignature("setGreeting(string)", "Hello from L1")
    });

    _crossChainRelayer.relayCalls(_calls, 1000000);
  }

  function run() public {
    vm.broadcast();

    bridgeToOptimism();

    vm.stopBroadcast();
  }
}
