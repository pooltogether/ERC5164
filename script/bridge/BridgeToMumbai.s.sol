// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";

import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { IMessageDispatcher } from "../../src/interfaces/IMessageDispatcher.sol";
import { MessageDispatcherPolygon } from "../../src/ethereum-polygon/EthereumToPolygonDispatcher.sol";
import "../../src/libraries/CallLib.sol";

contract BridgeToMumbai is DeployedContracts {
  function bridgeToMumbai() public {
    MessageDispatcherPolygon _messageDispatcher = _getMessageDispatcherPolygon();
    address _greeter = address(_getGreeterPolygon());

    CallLib.Call memory _call = CallLib.Call({
      to: _greeter,
      data: abi.encodeWithSignature("setGreeting(string)", "Hello from L1")
    });

    _messageDispatcher.dispatchMessage(_call);
  }

  function run() public {
    vm.broadcast();

    bridgeToMumbai();

    vm.stopBroadcast();
  }
}
