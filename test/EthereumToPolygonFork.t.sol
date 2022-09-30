// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { ICrossChainRelayer } from "../src/interfaces/ICrossChainRelayer.sol";
import { ICrossChainExecutor } from "../src/interfaces/ICrossChainExecutor.sol";

import "../src/relayers/CrossChainRelayerPolygon.sol";
import "../src/executors/CrossChainExecutorPolygon.sol";

import "./Greeter.sol";

contract EthereumToPolygonForkTest is Test {
  uint256 public mainnetFork;
  uint256 public polygonFork;

  CrossChainRelayerPolygon public relayer;
  CrossChainExecutorPolygon public executor;
  Greeter public greeter;

  address public checkpointManager = 0x86E4Dc95c7FBdBf52e33D563BbDB00823894C287;
  address public fxRoot = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;
  address public fxChild = 0x8397259c983751DAf40400790063935a11afa28a;

  string public greeterL1Greeting = "Hello from L1";
  string public greeterL2Greeting = "Hello from L2";

  uint256 public maxGasLimit = 1920000;
  uint256 public nonce = 1;

  /* ============ Events to test ============ */

  event RelayedCalls(
    uint256 indexed nonce,
    address indexed sender,
    ICrossChainExecutor indexed executor,
    ICrossChainRelayer.Call[] calls,
    uint256 gasLimit
  );

  event ExecutedCalls(
    ICrossChainRelayer indexed relayer,
    uint256 indexed nonce,
    address indexed caller,
    ICrossChainExecutor.Call[] calls
  );

  event SetGreeting(string greeting, address l1Sender, address l2Sender);

  event FailedRelayedMessage(bytes32 indexed msgHash);

  /* ============ Errors to test ============ */

  error CallFailure(ICrossChainExecutor.Call call, bytes errorData);

  /* ============ Setup ============ */

  function setUp() public {
    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    polygonFork = vm.createFork(vm.rpcUrl("polygon"));
  }

  function deployRelayer() public {
    vm.selectFork(mainnetFork);

    relayer = new CrossChainRelayerPolygon(checkpointManager, fxRoot, maxGasLimit);

    vm.makePersistent(address(relayer));
  }

  function deployExecutor() public {
    vm.selectFork(polygonFork);

    executor = new CrossChainExecutorPolygon(fxChild);

    vm.makePersistent(address(executor));
  }

  function deployGreeter() public {
    vm.selectFork(polygonFork);

    greeter = new Greeter(address(executor), greeterL2Greeting);

    vm.makePersistent(address(greeter));
  }

  function deployAll() public {
    deployRelayer();
    deployExecutor();
    deployGreeter();
  }

  function setFxChildTunnel() public {
    vm.selectFork(mainnetFork);
    relayer.setFxChildTunnel(address(executor));
  }

  function setFxRootTunnel() public {
    vm.selectFork(polygonFork);
    executor.setFxRootTunnel(address(relayer));
  }

  function setAll() public {
    setFxChildTunnel();
    setFxRootTunnel();
  }

  /* ============ Tests ============ */

  function testRelayer() public {
    deployRelayer();
    deployExecutor();
    setFxChildTunnel();

    assertEq(address(relayer.checkpointManager()), checkpointManager);
    assertEq(address(relayer.fxRoot()), fxRoot);
    assertEq(relayer.maxGasLimit(), maxGasLimit);

    assertEq(relayer.fxChildTunnel(), address(executor));
  }

  function testExecutor() public {
    deployExecutor();
    deployRelayer();
    setFxRootTunnel();

    assertEq(executor.fxChild(), fxChild);
    assertEq(executor.fxRootTunnel(), address(relayer));
  }

  function testGreeter() public {
    deployExecutor();
    deployGreeter();

    assertEq(greeter.greeting(), greeterL2Greeting);
  }

  function testRelayCalls() public {
    deployAll();

    vm.selectFork(mainnetFork);

    ICrossChainRelayer.Call[] memory _calls = new ICrossChainRelayer.Call[](1);

    _calls[0] = ICrossChainRelayer.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", greeterL1Greeting)
    });

    vm.expectEmit(true, true, true, true, address(relayer));

    emit RelayedCalls(
      nonce,
      address(this),
      ICrossChainExecutor(relayer.fxChildTunnel()),
      _calls,
      200000
    );

    relayer.relayCalls(_calls, 200000);
  }

  function testExecuteCalls() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    assertEq(greeter.greet(), greeterL2Greeting);

    ICrossChainExecutor.Call[] memory _calls = new ICrossChainExecutor.Call[](1);

    _calls[0] = ICrossChainExecutor.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", greeterL1Greeting)
    });

    vm.startPrank(fxChild);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(greeterL1Greeting, address(this), address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedCalls(relayer, nonce, fxChild, _calls);

    executor.processMessageFromRoot(1, address(relayer), abi.encode(nonce, address(this), _calls));

    assertEq(greeter.greet(), greeterL1Greeting);
  }

  function testGasLimitTooHigh() public {
    deployAll();

    vm.selectFork(mainnetFork);

    ICrossChainRelayer.Call[] memory _calls = new ICrossChainRelayer.Call[](1);

    _calls[0] = ICrossChainRelayer.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", greeterL1Greeting)
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        CrossChainRelayerPolygon.GasLimitTooHigh.selector,
        2000000,
        maxGasLimit
      )
    );

    relayer.relayCalls(_calls, 2000000);
  }

  function testCallFailure() public {
    deployAll();
    setAll();

    vm.selectFork(polygonFork);

    ICrossChainExecutor.Call[] memory _calls = new ICrossChainExecutor.Call[](1);

    _calls[0] = ICrossChainExecutor.Call({
      target: address(this),
      data: abi.encodeWithSignature("setGreeting(string)", greeterL1Greeting)
    });

    vm.startPrank(fxChild);

    vm.expectRevert(
      abi.encodeWithSelector(CrossChainExecutorPolygon.CallFailure.selector, _calls[0], bytes(""))
    );

    executor.processMessageFromRoot(1, address(relayer), abi.encode(nonce, address(this), _calls));
  }

  function testSetGreetingError() public {
    deployAll();

    vm.selectFork(polygonFork);

    vm.expectRevert(bytes("Greeter/caller-not-executor"));

    greeter.setGreeting(greeterL2Greeting);
  }
}
