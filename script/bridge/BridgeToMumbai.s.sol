// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";

import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { ICrossChainRelayer } from "../../src/interfaces/ICrossChainRelayer.sol";
import { CrossChainRelayerPolygon } from "../../src/ethereum-polygon/EthereumToPolygonRelayer.sol";
import "../../src/libraries/CallLib.sol";

contract BridgeToMumbai is DeployedContracts {
  function bridgeToMumbai() public {
    CrossChainRelayerPolygon _crossChainRelayer = _getCrossChainRelayerPolygon();
    address _greeter = address(_getGreeterPolygon());

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      target: _greeter,
      data: abi.encodeWithSignature("setGreeting(string)", "Hello from L1")
    });

    _crossChainRelayer.relayCalls(_calls, 1000000);
  }

  function run() public {
    vm.broadcast();

    bridgeToMumbai();

    vm.stopBroadcast();
  }
}
