//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "../../src/abstract/ExecutorAware.sol";

contract Greeter is ExecutorAware {
  string public greeting;

  event SetGreeting(
    string greeting,
    bytes32 messageId, // ID of the message that was executed
    uint256 fromChainId, // ID of the chain that dispatched the message
    address from, // _msgSender() is the address who dispatched the message on the origin chain
    address l2Sender // MessageExecutor contract
  );

  constructor(address _executor, string memory _greeting) ExecutorAware(_executor) {
    greeting = _greeting;
  }

  function greet() public view returns (string memory) {
    return greeting;
  }

  function setGreeting(string memory _greeting) public {
    require(isTrustedExecutor(msg.sender), "Greeter/sender-not-executor");

    greeting = _greeting;
    emit SetGreeting(_greeting, _messageId(), _fromChainId(), _msgSender(), msg.sender);
  }
}
