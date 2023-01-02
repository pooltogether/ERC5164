// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { CrossChainExecutorArbitrum } from "../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import { CrossChainRelayerArbitrum } from "../../src/ethereum-arbitrum/EthereumToArbitrumRelayer.sol";
import { Greeter } from "../../test/contracts/Greeter.sol";

contract DeployCrossChainRelayerToGoerli is Script {
  address public delayedInbox = 0x6BEbC4925716945D46F0Ec336D5C2564F419682C;

  function run() public {
    vm.broadcast();

    new CrossChainRelayerArbitrum(IInbox(delayedInbox));

    vm.stopBroadcast();
  }
}

contract DeployCrossChainExecutorToArbitrumGoerli is Script {
  function run() public {
    vm.broadcast();

    new CrossChainExecutorArbitrum();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying CrossChainRelayer and CrossChainExecutor
contract SetCrossChainExecutor is DeployedContracts {
  function setCrossChainExecutor() public {
    CrossChainRelayerArbitrum _crossChainRelayer = _getCrossChainRelayerArbitrum();
    CrossChainExecutorArbitrum _crossChainExecutor = _getCrossChainExecutorArbitrum();

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
    CrossChainRelayerArbitrum _crossChainRelayer = _getCrossChainRelayerArbitrum();
    CrossChainExecutorArbitrum _crossChainExecutor = _getCrossChainExecutorArbitrum();

    _crossChainExecutor.setRelayer(_crossChainRelayer);
  }

  function run() public {
    vm.broadcast();

    setCrossChainRelayer();

    vm.stopBroadcast();
  }
}

contract DeployGreeterToArbitrumGoerli is DeployedContracts {
  function deployGreeter() public {
    CrossChainExecutorArbitrum _crossChainExecutor = _getCrossChainExecutorArbitrum();
    new Greeter(address(_crossChainExecutor), "Hello from L2");
  }

  function run() public {
    vm.broadcast();

    deployGreeter();

    vm.stopBroadcast();
  }
}
