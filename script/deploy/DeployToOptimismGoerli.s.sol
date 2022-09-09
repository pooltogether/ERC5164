// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";
import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../../src/executors/CrossChainExecutorOptimism.sol";
import "../../test/Greeter.sol";

contract DeployToOptimismGoerli is Script {
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;
  address public crossChainExecutorOptimism = 0xDa2aF7350d82899123c24d8e94Ec94aBb7bbC357;

  function deployCrossChainExecutorOptimism() public {
    new CrossChainExecutorOptimism(IOptimismBridge(l2CrossDomainMessenger));
  }

  function deployGreeter() public {
    new Greeter(crossChainExecutorOptimism, "Hello from L2");
  }

  function run() public {
    vm.broadcast();

    deployGreeter();

    vm.stopBroadcast();
  }
}
