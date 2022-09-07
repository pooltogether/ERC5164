//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../src/ReceiverAware.sol";

contract Greeter is ReceiverAware {
  string public greeting;

  event SetGreeting(
    string greeting,
    address l1Sender, // _msgSender() is the address who called `relayCalls` on the origin chain
    address l2Sender, // CrossChainReceiver contract
    address origin // tx.origin
  );

  constructor(address _receiver, string memory _greeting) ReceiverAware(_receiver) {
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
