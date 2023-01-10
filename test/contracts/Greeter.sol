//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "../../src/abstract/ExecutorAware.sol";

contract Greeter is ExecutorAware {
  string public greeting;

  event SetGreeting(
    string greeting,
    uint256 nonce, // nonce of the message that was executed
    address from, // _msgSender() is the address who called `dispatchMessages` on the origin chain
    uint256 fromChainId, // ID of the chain that relayed the calls
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
    emit SetGreeting(_greeting, _nonce(), _msgSender(), _fromChainId(), msg.sender);
  }
}
