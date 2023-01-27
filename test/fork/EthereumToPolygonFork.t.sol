// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { IMessageDispatcher } from "../../src/interfaces/IMessageDispatcher.sol";
import { IMessageExecutor } from "../../src/interfaces/IMessageExecutor.sol";

import "../../src/ethereum-polygon/EthereumToPolygonDispatcher.sol";
import "../../src/ethereum-polygon/EthereumToPolygonExecutor.sol";
import "../../src/libraries/MessageLib.sol";

import { Greeter } from "../contracts/Greeter.sol";

contract EthereumToPolygonForkTest is Test {
  uint256 public mainnetFork;
  uint256 public polygonFork;

  MessageDispatcherPolygon public dispatcher;
  MessageExecutorPolygon public executor;
  Greeter public greeter;

  address public checkpointManager = 0x86E4Dc95c7FBdBf52e33D563BbDB00823894C287;
  address public fxRoot = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;
  address public fxChild = 0x8397259c983751DAf40400790063935a11afa28a;

  string public l1Greeting = "Hello from L1";
  string public l2Greeting = "Hello from L2";

  uint256 public nonce = 1;
  uint256 public toChainId = 137;
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

  /* ============ Errors to test ============ */

  error MessageFailure(uint256 messageIndex, bytes errorData);

  /* ============ Setup ============ */

  function setUp() public {
    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    polygonFork = vm.createFork(vm.rpcUrl("polygon"));
  }

  function deployDispatcher() public {
    vm.selectFork(mainnetFork);

    dispatcher = new MessageDispatcherPolygon(checkpointManager, fxRoot, toChainId);

    vm.makePersistent(address(dispatcher));
  }

  function deployExecutor() public {
    vm.selectFork(polygonFork);

    executor = new MessageExecutorPolygon(fxChild);

    vm.makePersistent(address(executor));
  }

  function deployGreeter() public {
    vm.selectFork(polygonFork);

    greeter = new Greeter(address(executor), l2Greeting);

    vm.makePersistent(address(greeter));
  }

  function deployAll() public {
    deployDispatcher();
    deployExecutor();
    deployGreeter();
  }

  function setFxChildTunnel() public {
    vm.selectFork(mainnetFork);
    dispatcher.setFxChildTunnel(address(executor));
  }

  function setFxRootTunnel() public {
    vm.selectFork(polygonFork);
    executor.setFxRootTunnel(address(dispatcher));
  }

  function setAll() public {
    setFxChildTunnel();
    setFxRootTunnel();
  }

  /* ============ Tests ============ */
  function testDispatcher() public {
    deployDispatcher();
    deployExecutor();
    setFxChildTunnel();

    assertEq(address(dispatcher.checkpointManager()), checkpointManager);
    assertEq(address(dispatcher.fxRoot()), fxRoot);

    assertEq(dispatcher.fxChildTunnel(), address(executor));
  }

  function testExecutor() public {
    deployExecutor();
    deployDispatcher();
    setFxRootTunnel();

    assertEq(executor.fxChild(), fxChild);
    assertEq(executor.fxRootTunnel(), address(dispatcher));
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

  function testDispatchMessageFxChildTunnelNotSet() public {
    deployAll();

    vm.selectFork(mainnetFork);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    vm.expectRevert(bytes("Dispatcher/fxChildTunnel-not-set"));
    dispatcher.dispatchMessage(toChainId, _to, _data);
  }

  function testDispatchMessageChainIdNotSupported() public {
    deployAll();
    setAll();

    vm.selectFork(mainnetFork);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    vm.expectRevert(bytes("Dispatcher/chainId-not-supported"));
    dispatcher.dispatchMessage(10, _to, _data);
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

  function testDispatchMessageBatchFxChildTunnelNotSet() public {
    deployAll();

    vm.selectFork(mainnetFork);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    vm.expectRevert(bytes("Dispatcher/fxChildTunnel-not-set"));
    dispatcher.dispatchMessageBatch(toChainId, _messages);
  }

  function testDispatchMessageBatchChainIdNotSupported() public {
    deployAll();
    setAll();

    vm.selectFork(mainnetFork);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    vm.expectRevert(bytes("Dispatcher/chainId-not-supported"));
    dispatcher.dispatchMessageBatch(10, _messages);
  }

  /* ============ executeMessage ============ */
  function testExecuteMessage() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    assertEq(greeter.greet(), l2Greeting);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({ to: _to, data: _data });

    vm.startPrank(fxChild);

    bytes32 _expectedMessageId = MessageLib.computeMessageId(nonce, address(this), _to, _data);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, _expectedMessageId, fromChainId, address(this), address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit MessageIdExecuted(fromChainId, _expectedMessageId);

    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_messages, _expectedMessageId, fromChainId, address(this))
    );

    assertEq(greeter.greet(), l1Greeting);
  }

  function testExecuteMessageToNotZeroAddress() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    assertEq(greeter.greet(), l2Greeting);

    address _to = address(0);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({ to: _to, data: _data });

    vm.startPrank(fxChild);

    bytes32 _expectedMessageId = MessageLib.computeMessageId(nonce, address(this), _to, _data);

    vm.expectRevert(bytes("MessageLib/no-contract-at-to"));
    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_messages, _expectedMessageId, fromChainId, address(this))
    );
  }

  function testExecuteMessageFailure() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    address _to = address(this);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (l1Greeting));

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({ to: _to, data: _data });

    vm.startPrank(fxChild);

    bytes32 _expectedMessageId = MessageLib.computeMessageId(nonce, address(this), _to, _data);

    vm.expectRevert(
      abi.encodeWithSelector(MessageLib.MessageFailure.selector, _expectedMessageId, bytes(""))
    );

    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_messages, _expectedMessageId, fromChainId, address(this))
    );
  }

  /* ============ executeMessageBatch ============ */
  function testExecuteMessageBatch() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    assertEq(greeter.greet(), l2Greeting);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](2);
    _messages[0] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    _messages[1] = MessageLib.Message({
      to: address(greeter),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    vm.startPrank(fxChild);

    bytes32 _expectedMessageId = MessageLib.computeMessageBatchId(nonce, address(this), _messages);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, _expectedMessageId, fromChainId, address(this), address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit MessageIdExecuted(fromChainId, _expectedMessageId);

    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_messages, _expectedMessageId, fromChainId, address(this))
    );

    assertEq(greeter.greet(), l1Greeting);
  }

  function testExecuteMessageBatchToNotZeroAddress() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    assertEq(greeter.greet(), l2Greeting);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](2);
    _messages[0] = MessageLib.Message({
      to: address(0),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    _messages[0] = MessageLib.Message({
      to: address(0),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    vm.startPrank(fxChild);

    bytes32 _expectedMessageId = MessageLib.computeMessageBatchId(nonce, address(this), _messages);

    vm.expectRevert(bytes("MessageLib/no-contract-at-to"));
    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_messages, _expectedMessageId, fromChainId, address(this))
    );
  }

  function testExecuteMessageBatchFailure() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](2);
    _messages[0] = MessageLib.Message({
      to: address(this),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    _messages[1] = MessageLib.Message({
      to: address(this),
      data: abi.encodeCall(Greeter.setGreeting, (l1Greeting))
    });

    vm.startPrank(fxChild);

    bytes32 _expectedMessageId = MessageLib.computeMessageBatchId(nonce, address(this), _messages);

    vm.expectRevert(
      abi.encodeWithSelector(
        MessageLib.MessageBatchFailure.selector,
        _expectedMessageId,
        0,
        bytes("")
      )
    );

    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_messages, _expectedMessageId, fromChainId, address(this))
    );
  }

  /* ============ setGreeting ============ */
  function testSetGreetingError() public {
    deployAll();

    vm.selectFork(polygonFork);

    vm.expectRevert(bytes("Greeter/sender-not-executor"));

    greeter.setGreeting(l2Greeting);
  }

  /* ============ getMessageExecutorAddress ============ */
  function testGetMessageExecutorAddress() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    address _executorAddress = dispatcher.getMessageExecutorAddress(toChainId);

    assertEq(_executorAddress, address(executor));
  }

  function testGetMessageExecutorAddressChainIdUnsupported() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    vm.expectRevert(bytes("Dispatcher/chainId-not-supported"));

    dispatcher.getMessageExecutorAddress(10);
  }
}
