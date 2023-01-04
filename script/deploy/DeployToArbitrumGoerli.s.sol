// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { MessageExecutorArbitrum } from "../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import { MessageDispatcherArbitrum } from "../../src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";
import { Greeter } from "../../test/contracts/Greeter.sol";

contract DeployMessageDispatcherToGoerli is Script {
  address public delayedInbox = 0x6BEbC4925716945D46F0Ec336D5C2564F419682C;

  function run() public {
    vm.broadcast();

    new MessageDispatcherArbitrum(IInbox(delayedInbox), 421613);

    vm.stopBroadcast();
  }
}

contract DeployMessageExecutorToArbitrumGoerli is Script {
  function run() public {
    vm.broadcast();

    new MessageExecutorArbitrum();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetMessageExecutor is DeployedContracts {
  function setMessageExecutor() public {
    MessageDispatcherArbitrum _messageDispatcher = _getMessageDispatcherArbitrum();
    MessageExecutorArbitrum _messageExecutor = _getMessageExecutorArbitrum();

    _messageDispatcher.setExecutor(_messageExecutor);
  }

  function run() public {
    vm.broadcast();

    setMessageExecutor();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetMessageDispatcher is DeployedContracts {
  function setMessageDispatcher() public {
    MessageDispatcherArbitrum _messageDispatcher = _getMessageDispatcherArbitrum();
    MessageExecutorArbitrum _messageExecutor = _getMessageExecutorArbitrum();

    _messageExecutor.setDispatcher(_messageDispatcher);
  }

  function run() public {
    vm.broadcast();

    setMessageDispatcher();

    vm.stopBroadcast();
  }
}

contract DeployGreeterToArbitrumGoerli is DeployedContracts {
  function deployGreeter() public {
    MessageExecutorArbitrum _messageExecutor = _getMessageExecutorArbitrum();
    new Greeter(address(_messageExecutor), "Hello from L2");
  }

  function run() public {
    vm.broadcast();

    deployGreeter();

    vm.stopBroadcast();
  }
}
