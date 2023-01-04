// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { MessageDispatcherArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";
import { MessageExecutorArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import { IMessageDispatcher } from "../../../src/interfaces/IMessageDispatcher.sol";
import "../../../src/libraries/MessageLib.sol";

import { Greeter } from "../../contracts/Greeter.sol";
import { ArbInbox } from "../../contracts/mock/ArbInbox.sol";

contract MessageDispatcherArbitrumUnitTest is Test {
  ArbInbox public inbox = new ArbInbox();
  MessageExecutorArbitrum public executor =
    MessageExecutorArbitrum(0x77E395E2bfCE67C718C8Ab812c86328EaE356f07);
  Greeter public greeter = Greeter(0x720003dC4EA5aCDA0204823B98E014f095E667f8);

  address public from = 0xa3a935315931A09A4e9B8A865517Cc18923497Ad;
  address public attacker = 0xdBdDa361Db11Adf8A51dab8a511a8ee89128E89A;

  uint256 public gasLimit = 1000000;

  uint256 public toChainId = 42161;

  uint256 public maxSubmissionCost = 1 ether;
  uint256 public gasPriceBid = 500;
  uint256 public nonce = 1;

  string public l1Greeting = "Hello from L1";

  MessageDispatcherArbitrum public dispatcher;
  MessageLib.Message[] public messages;

  /* ============ Events to test ============ */
  event MessageDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    address to,
    bytes data
  );

  event MessageBatchDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    MessageLib.Message[] messages
  );

  event MessageProcessed(
    bytes32 indexed messageId,
    address indexed sender,
    uint256 indexed ticketId
  );

  event MessageBatchProcessed(
    bytes32 indexed messageId,
    address indexed sender,
    uint256 indexed ticketId
  );

  /* ============ Setup ============ */
  function setUp() public {
    dispatcher = new MessageDispatcherArbitrum(inbox, toChainId);

    messages.push(
      MessageLib.Message({
        to: address(greeter),
        data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
      })
    );
  }

  function setExecutor() public {
    dispatcher.setExecutor(executor);
  }

  /* ============ Constructor ============ */
  function testConstructor() public {
    assertEq(address(dispatcher.inbox()), address(inbox));
  }

  function testConstructorInboxFail() public {
    vm.expectRevert(bytes("Dispatcher/inbox-not-zero-adrs"));
    dispatcher = new MessageDispatcherArbitrum(IInbox(address(0)), toChainId);
  }

  function testConstructorToChainIdFail() public {
    vm.expectRevert(bytes("Dispatcher/chainId-not-zero"));
    dispatcher = new MessageDispatcherArbitrum(inbox, 0);
  }

  /* ============ Dispatch ============ */
  function testDispatchMessage() public {
    setExecutor();

    MessageLib.Message memory _message = messages[0];
    bytes32 _expectedMessageId = MessageLib.computeMessageId(
      nonce,
      address(this),
      _message.to,
      _message.data
    );

    vm.expectEmit(true, true, true, true, address(dispatcher));
    emit MessageDispatched(
      _expectedMessageId,
      address(this),
      toChainId,
      _message.to,
      _message.data
    );

    bytes32 _messageId = dispatcher.dispatchMessage(toChainId, _message.to, _message.data);

    assertEq(_messageId, _expectedMessageId);

    bytes32 _txHash = dispatcher.getMessageTxHash(
      _messageId,
      address(this),
      _message.to,
      _message.data
    );
    assertTrue(dispatcher.dispatched(_txHash));
  }

  function testDispatchMessageBatch() public {
    setExecutor();

    bytes32 _expectedMessageId = MessageLib.computeMessageBatchId(nonce, address(this), messages);

    vm.expectEmit(true, true, true, true, address(dispatcher));
    emit MessageBatchDispatched(_expectedMessageId, address(this), toChainId, messages);

    bytes32 _messageId = dispatcher.dispatchMessageBatch(toChainId, messages);
    assertEq(_messageId, _expectedMessageId);

    bytes32 _txHash = dispatcher.getMessageBatchTxHash(_messageId, address(this), messages);
    assertTrue(dispatcher.dispatched(_txHash));
  }

  /* ============ Process ============ */

  function testProcessMessage() public {
    setExecutor();

    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = dispatcher.dispatchMessage(toChainId, _message.to, _message.data);

    bytes32 _expectedMessageId = MessageLib.computeMessageId(
      nonce,
      address(this),
      _message.to,
      _message.data
    );

    assertEq(_messageId, _expectedMessageId);

    uint256 _randomNumber = inbox.generateRandomNumber();

    vm.expectEmit(true, true, true, true, address(dispatcher));
    emit MessageProcessed(_messageId, address(this), _randomNumber);

    uint256 _ticketId = dispatcher.processMessage(
      _messageId,
      address(this),
      _message.to,
      _message.data,
      msg.sender,
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );

    assertEq(_ticketId, _randomNumber);
  }

  function testProcessMessageBatch() public {
    setExecutor();

    bytes32 _messageId = dispatcher.dispatchMessageBatch(toChainId, messages);
    bytes32 _expectedMessageId = MessageLib.computeMessageBatchId(nonce, address(this), messages);

    assertEq(_messageId, _expectedMessageId);

    uint256 _randomNumber = inbox.generateRandomNumber();

    vm.expectEmit(true, true, true, true, address(dispatcher));
    emit MessageBatchProcessed(_messageId, address(this), _randomNumber);

    uint256 _ticketId = dispatcher.processMessageBatch(
      _messageId,
      messages,
      address(this),
      msg.sender,
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );

    assertEq(_ticketId, _randomNumber);
  }

  /* ============ Requires ============ */

  function testMessageNotDispatched() public {
    setExecutor();

    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = MessageLib.computeMessageId(
      nonce,
      address(this),
      _message.to,
      _message.data
    );

    vm.expectRevert(bytes("Dispatcher/msg-not-dispatched"));
    dispatcher.processMessage(
      _messageId,
      address(this),
      _message.to,
      _message.data,
      msg.sender,
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );
  }

  function testMessagesNotDispatched() public {
    setExecutor();

    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, address(this), messages);

    vm.expectRevert(bytes("Dispatcher/msges-not-dispatched"));
    dispatcher.processMessageBatch(
      _messageId,
      messages,
      address(this),
      msg.sender,
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );
  }

  function testChainIdNotSupported() public {
    setExecutor();

    MessageLib.Message memory _message = messages[0];

    vm.expectRevert(bytes("Dispatcher/chainId-not-supported"));
    dispatcher.dispatchMessage(10, _message.to, _message.data);
  }

  function testExecutorNotSet() public {
    bytes32 _messageId = dispatcher.dispatchMessageBatch(toChainId, messages);

    vm.expectRevert(bytes("Dispatcher/executor-not-set"));
    dispatcher.processMessageBatch(
      _messageId,
      messages,
      address(this),
      msg.sender,
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );
  }

  function testRefundAddressNotZero() public {
    setExecutor();

    bytes32 _messageId = dispatcher.dispatchMessageBatch(toChainId, messages);

    vm.expectRevert(bytes("Dispatcher/refund-not-zero-adrs"));
    dispatcher.processMessageBatch(
      _messageId,
      messages,
      address(this),
      address(0),
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );
  }

  /* ============ Getters ============ */
  function testGetMessageTxHash() public {
    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = MessageLib.computeMessageId(nonce, from, _message.to, _message.data);

    bytes32 _txHash = dispatcher.getMessageTxHash(_messageId, from, _message.to, _message.data);
    bytes32 _txHashMatch = keccak256(
      abi.encode(address(dispatcher), _messageId, from, _message.to, _message.data)
    );

    assertEq(_txHash, _txHashMatch);
  }

  function testGetMessageTxHashFail() public {
    MessageLib.Message memory _message = messages[0];
    bytes32 _messageId = MessageLib.computeMessageId(nonce, from, _message.to, _message.data);

    bytes32 _txHash = dispatcher.getMessageTxHash(_messageId, from, _message.to, _message.data);
    bytes32 _txHashForged = keccak256(
      abi.encode(address(dispatcher), _messageId, attacker, _message.to, _message.data)
    );

    assertTrue(_txHash != _txHashForged);
  }

  function testGetMessageBatchTxHash() public {
    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, from, messages);

    bytes32 _txHash = dispatcher.getMessageBatchTxHash(_messageId, from, messages);
    bytes32 _txHashMatch = keccak256(abi.encode(address(dispatcher), _messageId, from, messages));

    assertEq(_txHash, _txHashMatch);
  }

  function testGetMessageBatchTxHashFail() public {
    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, from, messages);

    bytes32 _txHash = dispatcher.getMessageBatchTxHash(_messageId, from, messages);
    bytes32 _txHashForged = keccak256(
      abi.encode(address(dispatcher), _messageId, attacker, messages)
    );

    assertTrue(_txHash != _txHashForged);
  }

  function testGetMessageExecutorAddress() public {
    setExecutor();

    address _executorAddress = dispatcher.getMessageExecutorAddress(toChainId);
    assertEq(_executorAddress, address(executor));
  }

  function testGetMessageExecutorAddressFail() public {
    setExecutor();

    vm.expectRevert(bytes("Dispatcher/chainId-not-supported"));
    dispatcher.getMessageExecutorAddress(10);
  }

  /* ============ Setters ============ */
  function testSetExecutor() public {
    setExecutor();

    address _executorAddress = dispatcher.getMessageExecutorAddress(toChainId);
    assertEq(_executorAddress, address(executor));
  }

  function testSetExecutorFail() public {
    setExecutor();

    vm.expectRevert(bytes("Dispatcher/executor-already-set"));
    dispatcher.setExecutor(MessageExecutorArbitrum(address(0)));
  }
}
