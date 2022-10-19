//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../../src/abstract/ExecutorAware.sol";

contract Greeter is ExecutorAware {
  string public greeting;

  event SetGreeting(
    string greeting,
    uint256 nonce, // nonce of the message that was executed
    address l1Sender, // _msgSender() is the address who called `relayCalls` on the origin chain
    address l2Sender // CrossChainExecutor contract
  );

  constructor(address _executor, string memory _greeting) ExecutorAware(_executor) {
    greeting = _greeting;
  }

  function greet() public view returns (string memory) {
    return greeting;
  }

  function setGreeting(string memory _greeting) public {
    require(isTrustedForwarder(msg.sender), "Greeter/caller-not-executor");

    greeting = _greeting;
    emit SetGreeting(_greeting, _nonce(), _msgSender(), msg.sender);
  }
}
