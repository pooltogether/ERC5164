// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { ICrossChainExecutor } from "../../src/interfaces/ICrossChainExecutor.sol";
import { ICrossChainRelayer } from "../../src/interfaces/ICrossChainRelayer.sol";

import { CrossChainExecutorOptimism } from "../../src/executors/CrossChainExecutorOptimism.sol";
import { CrossChainRelayerOptimism } from "../../src/relayers/CrossChainRelayerOptimism.sol";
import { Greeter } from "../../test/Greeter.sol";

contract DeployCrossChainRelayerToGoerli is Script {
  address public proxyOVML1CrossDomainMessenger = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;

  function deployCrossChainRelayerOptimism() public {
    new CrossChainRelayerOptimism(IOptimismBridge(proxyOVML1CrossDomainMessenger), 1920000);
  }

  function run() public {
    vm.broadcast();

    deployCrossChainRelayerOptimism();

    vm.stopBroadcast();
  }
}

contract DeployCrossChainExecutorToOptimismGoerli is Script {
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;

  function deployCrossChainExecutorOptimism() public {
    new CrossChainExecutorOptimism(IOptimismBridge(l2CrossDomainMessenger));
  }

  function run() public {
    vm.broadcast();

    deployCrossChainExecutorOptimism();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying CrossChainRelayer and CrossChainExecutor
contract SetCrossChainExecutor is DeployedContracts {
  function setCrossChainExecutor() public {
    vm.allowCheatcodes(address(this));

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
    vm.allowCheatcodes(address(this));

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
