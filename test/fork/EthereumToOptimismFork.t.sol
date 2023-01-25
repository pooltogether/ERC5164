// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { L2CrossDomainMessenger } from "@eth-optimism/contracts/L2/messaging/L2CrossDomainMessenger.sol";
import { AddressAliasHelper } from "@eth-optimism/contracts/standards/AddressAliasHelper.sol";

import { IMessageDispatcher } from "../../src/interfaces/IMessageDispatcher.sol";
import { IMessageExecutor } from "../../src/interfaces/IMessageExecutor.sol";

import "../../src/ethereum-optimism/EthereumToOptimismDispatcher.sol";
import "../../src/ethereum-optimism/EthereumToOptimismExecutor.sol";
import "../../src/libraries/MessageLib.sol";

import { Greeter } from "../contracts/Greeter.sol";

contract EthereumToOptimismForkTest is Test {
  uint256 public mainnetFork;
  uint256 public optimismFork;

  MessageDispatcherOptimism public dispatcher;
  MessageExecutorOptimism public executor;
  Greeter public greeter;

  address public proxyOVML1CrossDomainMessenger = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;

  string public l1Greeting = "Hello from L1";
  string public l2Greeting = "Hello from L2";

  uint256 public nonce = 1;
  uint256 public toChainId = 10;
  uint256 public fromChainId = 1;

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

  event MessageIdExecuted(uint256 indexed fromChainId, bytes32 indexed messageId);

  event SetGreeting(
    string greeting,
    bytes32 messageId,
    uint256 fromChainId,
    address from,
    address l2Sender
  );

  /* ============ Setup ============ */

  function setUp() public {
    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    optimismFork = vm.createFork(vm.rpcUrl("optimism"));
  }

  function deployDispatcher() public {
    vm.selectFork(mainnetFork);

    dispatcher = new MessageDispatcherOptimism(
      ICrossDomainMessenger(proxyOVML1CrossDomainMessenger),
      toChainId
    );

    vm.makePersistent(address(dispatcher));
  }

  function deployExecutor() public {
    vm.selectFork(optimismFork);

    executor = new MessageExecutorOptimism(ICrossDomainMessenger(l2CrossDomainMessenger));

    vm.makePersistent(address(executor));
  }

  function deployGreeter() public {
    vm.selectFork(optimismFork);

    greeter = new Greeter(address(executor), l2Greeting);

    vm.makePersistent(address(greeter));
  }

  function deployAll() public {
    deployDispatcher();
    deployExecutor();
    deployGreeter();
  }

  function setExecutor() public {
    vm.selectFork(mainnetFork);
    dispatcher.setExecutor(executor);
  }

  function setDispatcher() public {
    vm.selectFork(optimismFork);
    executor.setDispatcher(dispatcher);
  }

  function setAll() public {
    setExecutor();
    setDispatcher();
  }

  /* ============ Tests ============ */

  function testDispatcher() public {
    deployDispatcher();
    deployExecutor();
    setExecutor();

    address _executorAddress = dispatcher.getMessageExecutorAddress(toChainId);

    assertEq(address(dispatcher.crossDomainMessenger()), proxyOVML1CrossDomainMessenger);
    assertEq(_executorAddress, address(executor));
  }

  function testExecutor() public {
    deployDispatcher();
    deployExecutor();
    setDispatcher();

    assertEq(address(executor.crossDomainMessenger()), l2CrossDomainMessenger);
    assertEq(address(executor.dispatcher()), address(dispatcher));
  }

  function testGreeter() public {
    deployExecutor();
    deployGreeter();

    assertEq(greeter.greeting(), l2Greeting);
  }

  /* ============ dispatchMessage ============ */
  function testDispatchMessage() public {
    deployAll();
    setAll();

    vm.selectFork(mainnetFork);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    bytes32 _expectedMessageId = MessageLib.computeMessageId(nonce, address(this), _to, _data);

    vm.expectEmit(true, true, true, true, address(dispatcher));
    emit MessageDispatched(_expectedMessageId, address(this), toChainId, _to, _data);

    bytes32 _messageId = dispatcher.dispatchMessage(toChainId, _to, _data);

    assertEq(_messageId, _expectedMessageId);
  }

  function testDispatchMessageChainIdNotSupported() public {
    deployAll();

    vm.selectFork(mainnetFork);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    vm.expectRevert(bytes("Dispatcher/chainId-not-supported"));

    dispatcher.dispatchMessage(42161, _to, _data);
  }

  function testDispatchMessageExecutorNotSet() public {
    deployAll();

    vm.selectFork(mainnetFork);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    vm.expectRevert(bytes("Dispatcher/executor-not-set"));

    dispatcher.dispatchMessage(toChainId, _to, _data);
  }

  /* ============ dispatchMessageBatch ============ */
  function testDispatchMessageBatch() public {
    deployAll();
    setAll();

    vm.selectFork(mainnetFork);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    bytes32 _expectedMessageId = MessageLib.computeMessageBatchId(nonce, address(this), _messages);

    vm.expectEmit(true, true, true, true, address(dispatcher));
    emit MessageBatchDispatched(_expectedMessageId, address(this), toChainId, _messages);

    bytes32 _messageId = dispatcher.dispatchMessageBatch(toChainId, _messages);

    assertEq(_messageId, _expectedMessageId);
  }

  function testDispatchMessageBatchChainIdNotSupported() public {
    deployAll();

    vm.selectFork(mainnetFork);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, l1Greeting)
    });

    vm.expectRevert(bytes("Dispatcher/chainId-not-supported"));

    dispatcher.dispatchMessageBatch(42161, _messages);
  }

  function testDispatchMessageBatchExecutorNotSet() public {
    deployAll();

    vm.selectFork(mainnetFork);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    vm.expectRevert(bytes("Dispatcher/executor-not-set"));

    dispatcher.dispatchMessageBatch(toChainId, _messages);
  }

  /* ============ executeMessage ============ */

  function testExecuteMessage() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    assertEq(greeter.greet(), l2Greeting);

    L2CrossDomainMessenger l2Bridge = L2CrossDomainMessenger(l2CrossDomainMessenger);

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(proxyOVML1CrossDomainMessenger));

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    bytes32 _expectedMessageId = MessageLib.computeMessageId(nonce, address(this), _to, _data);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, _expectedMessageId, fromChainId, address(this), address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit MessageIdExecuted(fromChainId, _expectedMessageId);

    l2Bridge.relayMessage(
      address(executor),
      address(dispatcher),
      abi.encodeCall(
        IMessageExecutor.executeMessage,
        (_to, _data, _expectedMessageId, fromChainId, address(this))
      ),
      l2Bridge.messageNonce() + 1
    );

    assertEq(greeter.greet(), l1Greeting);
  }

  function testExecuteMessageIsUnauthorized() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    vm.expectRevert(bytes("Executor/sender-unauthorized"));

    bytes32 _messageId = MessageLib.computeMessageId(nonce, address(this), _to, _data);
    executor.executeMessage(_to, _data, _messageId, fromChainId, address(this));
  }

  /* ============ executeMessageBatch ============ */

  function testExecuteMessageBatch() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    assertEq(greeter.greet(), l2Greeting);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    L2CrossDomainMessenger l2Bridge = L2CrossDomainMessenger(l2CrossDomainMessenger);

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(proxyOVML1CrossDomainMessenger));

    bytes32 _expectedMessageId = MessageLib.computeMessageBatchId(nonce, address(this), _messages);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, _expectedMessageId, fromChainId, address(this), address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit MessageIdExecuted(fromChainId, _expectedMessageId);

    l2Bridge.relayMessage(
      address(executor),
      address(dispatcher),
      abi.encodeCall(
        IMessageExecutor.executeMessageBatch,
        (_messages, _expectedMessageId, fromChainId, address(this))
      ),
      l2Bridge.messageNonce() + 1
    );

    assertEq(greeter.greet(), l1Greeting);
  }

  function testExecuteMessageBatchIsUnauthorized() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    vm.expectRevert(bytes("Executor/sender-unauthorized"));

    bytes32 _messageId = MessageLib.computeMessageBatchId(nonce, address(this), _messages);
    executor.executeMessageBatch(_messages, _messageId, fromChainId, address(this));
  }

  /* ============ Setters ============ */
  function testSetGreetingError() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    vm.expectRevert(bytes("Greeter/sender-not-executor"));

    greeter.setGreeting(l2Greeting);
  }
}
