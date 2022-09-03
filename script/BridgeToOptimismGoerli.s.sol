// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";
import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import { ICrossChainRelayer } from "../src/interfaces/ICrossChainRelayer.sol";
import "../src/relayers/CrossChainRelayerOptimism.sol";
import "../src/receivers/CrossChainReceiverOptimism.sol";

contract BridgeToOptimismGoerli is Script {
  address public crossChainRelayerOptimism = 0x1580cD9d86098Ebfe8fFEdAef051AAD7FbfC4198;
  address public crossChainReceiverOptimism = 0xDa2aF7350d82899123c24d8e94Ec94aBb7bbC357;
  address public greeter = 0xCF4F1F77ba09E397ee5eF5d6916Bd4F6387ac228;

  string public greeterL1Greeting = "Hello from L1";

  function bridgeToOptimism() public {
    CrossChainRelayerOptimism _relayer = CrossChainRelayerOptimism(crossChainRelayerOptimism);
    CrossChainReceiverOptimism _receiver = CrossChainReceiverOptimism(crossChainReceiverOptimism);

    ICrossChainRelayer.Call[] memory _calls = new ICrossChainRelayer.Call[](1);

    _calls[0] = ICrossChainRelayer.Call({
      target: greeter,
      data: abi.encodeWithSignature("setGreeting(string)", greeterL1Greeting)
    });

    _relayer.relayCalls(_receiver, _calls, 1000000);
  }

  function run() public {
    vm.broadcast();

    bridgeToOptimism();

    vm.stopBroadcast();
  }
}
