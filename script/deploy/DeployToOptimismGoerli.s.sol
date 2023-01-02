// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { CrossChainExecutorOptimism } from "../../src/ethereum-optimism/EthereumToOptimismExecutor.sol";
import { CrossChainRelayerOptimism } from "../../src/ethereum-optimism/EthereumToOptimismRelayer.sol";
import { Greeter } from "../../test/contracts/Greeter.sol";

contract DeployCrossChainRelayerToGoerli is Script {
  address public proxyOVML1CrossDomainMessenger = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;

  function run() public {
    vm.broadcast();

    new CrossChainRelayerOptimism(ICrossDomainMessenger(proxyOVML1CrossDomainMessenger));

    vm.stopBroadcast();
  }
}

contract DeployCrossChainExecutorToOptimismGoerli is Script {
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;

  function run() public {
    vm.broadcast();

    new CrossChainExecutorOptimism(ICrossDomainMessenger(l2CrossDomainMessenger));

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying CrossChainRelayer and CrossChainExecutor
contract SetCrossChainExecutor is DeployedContracts {
  function setCrossChainExecutor() public {
    CrossChainRelayerOptimism _crossChainRelayer = _getCrossChainRelayerOptimism();
    CrossChainExecutorOptimism _crossChainExecutor = _getCrossChainExecutorOptimism();

    _crossChainRelayer.setExecutor(_crossChainExecutor);
  }

  function run() public {
    vm.broadcast();

    setCrossChainExecutor();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying CrossChainRelayer and CrossChainExecutor
contract SetCrossChainRelayer is DeployedContracts {
  function setCrossChainRelayer() public {
    CrossChainRelayerOptimism _crossChainRelayer = _getCrossChainRelayerOptimism();
    CrossChainExecutorOptimism _crossChainExecutor = _getCrossChainExecutorOptimism();

    _crossChainExecutor.setRelayer(_crossChainRelayer);
  }

  function run() public {
    vm.broadcast();

    setCrossChainRelayer();

    vm.stopBroadcast();
  }
}

contract DeployGreeterToOptimismGoerli is DeployedContracts {
  function deployGreeter() public {
    CrossChainExecutorOptimism _crossChainExecutor = _getCrossChainExecutorOptimism();
    new Greeter(address(_crossChainExecutor), "Hello from L2");
  }

  function run() public {
    vm.broadcast();

    deployGreeter();

    vm.stopBroadcast();
  }
}
