// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";
import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../src/receivers/CrossChainReceiverOptimism.sol";
import "../test/Greeter.sol";

contract DeployToOptimism is Script {
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;
  address public crossChainReceiverOptimism = 0xDa2aF7350d82899123c24d8e94Ec94aBb7bbC357;

  function deployCrossChainReceiverOptimism() public {
    new CrossChainReceiverOptimism(IOptimismBridge(l2CrossDomainMessenger));
  }

  function deployGreeter() public {
    new Greeter(crossChainReceiverOptimism, "Hello from L2");
  }

  function run() public {
    vm.broadcast();

    deployGreeter();

    vm.stopBroadcast();
  }
}
