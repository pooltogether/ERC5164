// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";

import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { IMessageDispatcher } from "../../src/interfaces/IMessageDispatcher.sol";
import { MessageDispatcherPolygon } from "../../src/ethereum-polygon/EthereumToPolygonDispatcher.sol";
import "../../src/libraries/MessageLib.sol";

import { Greeter } from "../../test/contracts/Greeter.sol";

contract BridgeToMumbai is DeployedContracts {
  function bridgeToMumbai() public {
    MessageDispatcherPolygon _messageDispatcher = _getMessageDispatcherPolygon();

    _messageDispatcher.dispatchMessage(
      80001,
      address(_getGreeterPolygon()),
      abi.encodeCall(Greeter.setGreeting, ("Hello from L1"))
    );
  }

  function run() public {
    vm.broadcast();

    bridgeToMumbai();

    vm.stopBroadcast();
  }
}
