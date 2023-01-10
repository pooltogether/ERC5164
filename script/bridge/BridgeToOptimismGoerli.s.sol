// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Script.sol";

import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import { IMessageDispatcher } from "../../src/interfaces/IMessageDispatcher.sol";
import { MessageDispatcherOptimism } from "../../src/ethereum-optimism/EthereumToOptimismDispatcher.sol";
import "../../src/libraries/CallLib.sol";

contract BridgeToOptimismGoerli is DeployedContracts {
  function bridgeToOptimism() public {
    MessageDispatcherOptimism _messageDispatcher = _getMessageDispatcherOptimism();
    address _greeter = address(_getGreeterOptimism());

    CallLib.Call memory _call = CallLib.Call({
      to: _greeter,
      data: abi.encodeWithSignature("setGreeting(string)", "Hello from L1")
    });

    _messageDispatcher.dispatchMessage(_call);
  }

  function run() public {
    vm.broadcast();

    bridgeToOptimism();

    vm.stopBroadcast();
  }
}
