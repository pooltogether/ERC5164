// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { AddressAliasHelper } from "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";
import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { IMessageDispatcher } from "../../../src/interfaces/IMessageDispatcher.sol";
import { MessageExecutorArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import { MessageDispatcherArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";
import "../../../src/libraries/MessageLib.sol";

import { Greeter } from "../../contracts/Greeter.sol";

contract MessageExecutorArbitrumUnitTest is Test {
  MessageDispatcherArbitrum public dispatcher =
    MessageDispatcherArbitrum(0x77E395E2bfCE67C718C8Ab812c86328EaE356f07);

  address public dispatcherAlias = AddressAliasHelper.applyL1ToL2Alias(address(dispatcher));

  address public from = 0xa3a935315931A09A4e9B8A865517Cc18923497Ad;
  address public attacker = 0xdBdDa361Db11Adf8A51dab8a511a8ee89128E89A;

  uint256 public nonce = 1;
  uint256 public fromChainId = 1;

  string public l1Greeting = "Hello from L1";

  MessageLib.Message[] public messages;
  MessageExecutorArbitrum public executor;
  Greeter public greeter;

  /* ============ Events to test ============ */
  event ExecutedMessage(
    uint256 indexed fromChainId,
    IMessageDispatcher indexed dispatcher,
    bytes32 indexed messageId
  );

  event ExecutedMessageBatch(
    uint256 indexed fromChainId,
    IMessageDispatcher indexed dispatcher,
    bytes32 indexed messageId
  );

  event SetGreeting(
    string greeting,
    bytes32 messageId,
    uint256 fromChainId,
    address from,
    address l2Sender
  );

  /* ============ Setup ============ */

  function setUp() public {
    executor = new MessageExecutorArbitrum();
    greeter = new Greeter(address(executor), "Hello from L2");
  }

  function pushMessages(address _to) public {
    messages.push(
      MessageLib.Message({
        to: _to,
        data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
      })
    );
  }

  function setDispatcher() public {
    executor.setDispatcher(dispatcher);
  }

  /* ============ ExecuteMessage ============ */
  function testExecuteMessage() public {
    setDispatcher();
    pushMessages(address(greeter));

    vm.startPrank(dispatcherAlias);

    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = MessageLib.computeMessageId(
      nonce,
      address(this),
      _message.to,
      _message.data
    );

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, _messageId, fromChainId, from, address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedMessage(fromChainId, dispatcher, _messageId);

    executor.executeMessage(_message.to, _message.data, _messageId, fromChainId, from);

    assertTrue(executor.executed(_messageId));
  }

  function testExecuteMessageIdAlreadyExecuted() public {
    setDispatcher();
    pushMessages(address(greeter));

    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = MessageLib.computeMessageId(
      nonce,
      address(this),
      _message.to,
      _message.data
    );

    vm.startPrank(dispatcherAlias);
    executor.executeMessage(_message.to, _message.data, _messageId, fromChainId, from);

    vm.expectRevert(
      abi.encodeWithSelector(MessageLib.MessageIdAlreadyExecuted.selector, _messageId)
    );

    executor.executeMessage(_message.to, _message.data, _messageId, fromChainId, from);
  }

  function testExecuteMessageFailure() public {
    setDispatcher();
    pushMessages(address(this));

    vm.startPrank(dispatcherAlias);

    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = MessageLib.computeMessageId(
      nonce,
      address(this),
      _message.to,
      _message.data
    );

    vm.expectRevert(
      abi.encodeWithSelector(MessageLib.MessageFailure.selector, _messageId, bytes(""))
    );

    executor.executeMessage(_message.to, _message.data, _messageId, fromChainId, from);
  }

  function testExecuteMessageUnauthorized() public {
    setDispatcher();
    pushMessages(address(greeter));

    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = MessageLib.computeMessageId(
      nonce,
      address(this),
      _message.to,
      _message.data
    );

    vm.expectRevert(bytes("Executor/sender-unauthorized"));
    executor.executeMessage(_message.to, _message.data, _messageId, fromChainId, from);
  }

  function testExecuteMessageToNotZeroAddress() public {
    setDispatcher();
    pushMessages(address(0));

    vm.startPrank(dispatcherAlias);

    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = MessageLib.computeMessageId(
      nonce,
      address(this),
      _message.to,
      _message.data
    );

    vm.expectRevert(bytes("MessageLib/no-contract-at-to"));
    executor.executeMessage(_message.to, _message.data, _messageId, fromChainId, from);
  }

  /* ============ ExecuteMessageBatch ============ */
  function testExecuteMessageBatch() public {
    setDispatcher();
    pushMessages(address(greeter));

    vm.startPrank(dispatcherAlias);

    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, msg.sender, messages);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, _messageId, fromChainId, from, address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedMessageBatch(fromChainId, dispatcher, _messageId);

    executor.executeMessageBatch(messages, _messageId, fromChainId, from);

    assertTrue(executor.executed(_messageId));
  }

  function testExecuteMessageBatchIdAlreadyExecuted() public {
    setDispatcher();
    pushMessages(address(greeter));

    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, msg.sender, messages);

    vm.startPrank(dispatcherAlias);
    executor.executeMessageBatch(messages, _messageId, fromChainId, from);

    vm.expectRevert(
      abi.encodeWithSelector(MessageLib.MessageIdAlreadyExecuted.selector, _messageId)
    );

    executor.executeMessageBatch(messages, _messageId, fromChainId, from);
  }

  function testExecuteMessageBatchFailure() public {
    setDispatcher();
    pushMessages(address(this));

    vm.startPrank(dispatcherAlias);

    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, msg.sender, messages);

    vm.expectRevert(
      abi.encodeWithSelector(MessageLib.MessageBatchFailure.selector, _messageId, 0, bytes(""))
    );

    executor.executeMessageBatch(messages, _messageId, fromChainId, from);
  }

  function testExecuteMessageBatchUnauthorized() public {
    setDispatcher();
    pushMessages(address(greeter));

    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, msg.sender, messages);

    vm.expectRevert(bytes("Executor/sender-unauthorized"));
    executor.executeMessageBatch(messages, _messageId, fromChainId, from);
  }

  function testExecuteMessageBatchToNotZeroAddress() public {
    setDispatcher();
    pushMessages(address(0));

    vm.startPrank(dispatcherAlias);

    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, msg.sender, messages);

    vm.expectRevert(bytes("MessageLib/no-contract-at-to"));
    executor.executeMessageBatch(messages, _messageId, fromChainId, from);
  }

  /* ============ Setters ============ */

  function testSetDispatcher() public {
    setDispatcher();
    assertEq(address(dispatcher), address(executor.dispatcher()));
  }

  function testSetDispatcherFail() public {
    setDispatcher();

    vm.expectRevert(bytes("Executor/dispatcher-already-set"));
    executor.setDispatcher(MessageDispatcherArbitrum(address(0)));
  }
}
