// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";
import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../src/relayers/CrossChainRelayerOptimism.sol";

contract DeployToEthereum is Script {
  address public proxyOVML1CrossDomainMessenger = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;

  function deployCrossChainRelayerOptimism() public {
    new CrossChainRelayerOptimism(IOptimismBridge(proxyOVML1CrossDomainMessenger));
  }

  function run() public {
    vm.broadcast();

    deployCrossChainRelayerOptimism();

    vm.stopBroadcast();
  }
}
