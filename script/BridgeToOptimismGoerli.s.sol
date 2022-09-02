// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";
import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import { ICrossChainRelayer } from "../src/interfaces/ICrossChainRelayer.sol";
import "../src/relayers/CrossChainRelayerOptimism.sol";
import "../src/receivers/CrossChainReceiverOptimism.sol";

contract BridgeToOptimismGoerli is Script {
  address public crossChainRelayerOptimism = 0xDb7bC6e3023C826a9AD2d349C6Ef647D87AfE6Bc;
  address public crossChainReceiverOptimism = 0x336273E1417506F79F79cB4c766218f0796D1073;
  address public greeter = 0x9A3E50B6327b3117EbfEDd70ca582b1bEda4762D;

  string public greeterL1Greeting = "Hello from L1";

  function bridgeToOptimism() public {
    CrossChainRelayerOptimism _relayer = CrossChainRelayerOptimism(crossChainRelayerOptimism);
    CrossChainReceiverOptimism _receiver = CrossChainReceiverOptimism(crossChainReceiverOptimism);

    ICrossChainRelayer.Call[] memory _calls = new ICrossChainRelayer.Call[](1);

    _calls[0] = ICrossChainRelayer.Call({
      target: greeter,
      data: abi.encodeWithSignature("setGreeting(string)", greeterL1Greeting),
      gasLimit: 1000000
    });

    _relayer.relayCalls(_receiver, _calls, 1000000);
  }

  function run() public {
    vm.broadcast();

    bridgeToOptimism();

    vm.stopBroadcast();
  }
}
