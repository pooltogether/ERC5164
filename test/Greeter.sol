//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../src/BridgeAware.sol";

contract Greeter is BridgeAware {
  string public greeting;

  event SetGreeting(
    string greeting,
    address l1Sender, // _msgSender() which is the L1 bridge
    address l2Sender, // CrossChainReceiver contract
    address origin // tx.origin
  );

  constructor(address _receiver, string memory _greeting) BridgeAware(_receiver) {
    greeting = _greeting;
  }

  function greet() public view returns (string memory) {
    return greeting;
  }

  function setGreeting(string memory _greeting) public {
    require(isTrustedForwarder(msg.sender), "Greeter/caller-not-receiver");

    greeting = _greeting;
    emit SetGreeting(_greeting, _msgSender(), msg.sender, tx.origin);
  }
}
