// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { IMessageDispatcher } from "../../src/interfaces/IMessageDispatcher.sol";
import { IMessageExecutor } from "../../src/interfaces/IMessageExecutor.sol";

import "../../src/ethereum-polygon/EthereumToPolygonDispatcher.sol";
import "../../src/ethereum-polygon/EthereumToPolygonExecutor.sol";
import "../../src/libraries/CallLib.sol";

import "../contracts/Greeter.sol";

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

  event RelayedCalls(
    uint256 indexed nonce,
    address indexed from,
    CallLib.Call[] calls,
    uint256 toChainId
  );

  event ExecutedCalls(
    uint256 indexed fromChainId,
    IMessageDispatcher indexed dispatcher,
    uint256 indexed nonce
  );

  event SetGreeting(
    string greeting,
    uint256 nonce,
    address from,
    uint256 fromChainId,
    address l2Sender
  );

  /* ============ Errors to test ============ */

  error CallFailure(uint256 callIndex, bytes errorData);

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

  function testRelayCalls() public {
    deployAll();
    setAll();

    vm.selectFork(mainnetFork);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      to: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.expectEmit(true, true, true, true, address(dispatcher));

    emit RelayedCalls(nonce, address(this), _calls, toChainId);

    uint256 _nonce = dispatcher.dispatchMessages(_calls);

    assertEq(_nonce, nonce);
  }

  function testFxChildTunnelNotSet() public {
    deployAll();

    vm.selectFork(mainnetFork);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      to: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.expectRevert(bytes("Dispatcher/fxChildTunnel-not-set"));

    dispatcher.dispatchMessages(_calls);
  }

  function testExecuteCalls() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    assertEq(greeter.greet(), l2Greeting);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      to: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.startPrank(fxChild);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, nonce, address(this), fromChainId, address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedCalls(fromChainId, dispatcher, nonce);

    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_calls, nonce, address(this), fromChainId)
    );

    assertEq(greeter.greet(), l1Greeting);
  }

  function testExecuteCallsToNotZeroAddress() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    assertEq(greeter.greet(), l2Greeting);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      to: address(0),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.startPrank(fxChild);

    vm.expectRevert(bytes("CallLib/no-contract-at-to"));
    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_calls, nonce, address(this), fromChainId)
    );
  }

  function testCallFailure() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      to: address(this),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.startPrank(fxChild);

    vm.expectRevert(
      abi.encodeWithSelector(
        MessageExecutorPolygon.ExecuteCallsFailed.selector,
        fromChainId,
        address(dispatcher),
        1
      )
    );

    executor.processMessageFromRoot(
      1,
      address(dispatcher),
      abi.encode(_calls, nonce, address(this), fromChainId)
    );
  }

  function testSetGreetingError() public {
    deployAll();

    vm.selectFork(polygonFork);

    vm.expectRevert(bytes("Greeter/sender-not-executor"));

    greeter.setGreeting(l2Greeting);
  }
}
