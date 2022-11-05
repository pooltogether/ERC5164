// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { L2CrossDomainMessenger } from "@eth-optimism/contracts/L2/messaging/L2CrossDomainMessenger.sol";
import { AddressAliasHelper } from "@eth-optimism/contracts/standards/AddressAliasHelper.sol";

import { ICrossChainRelayer } from "../../src/interfaces/ICrossChainRelayer.sol";
import { ICrossChainExecutor } from "../../src/interfaces/ICrossChainExecutor.sol";

import "../../src/ethereum-optimism/EthereumToOptimismRelayer.sol";
import "../../src/ethereum-optimism/EthereumToOptimismExecutor.sol";
import "../../src/libraries/CallLib.sol";

import "../contracts/Greeter.sol";

contract EthereumToOptimismForkTest is Test {
  uint256 public mainnetFork;
  uint256 public optimismFork;

  CrossChainRelayerOptimism public relayer;
  CrossChainExecutorOptimism public executor;
  Greeter public greeter;

  address public proxyOVML1CrossDomainMessenger = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;

  string public l1Greeting = "Hello from L1";
  string public l2Greeting = "Hello from L2";

  uint256 public maxGasLimit = 1920000;
  uint256 public nonce = 1;

  /* ============ Events to test ============ */

  event RelayedCalls(
    uint256 indexed nonce,
    address indexed sender,
    CallLib.Call[] calls,
    uint256 gasLimit
  );

  event ExecutedCalls(ICrossChainRelayer indexed relayer, uint256 indexed nonce);

  event SetGreeting(string greeting, uint256 nonce, address l1Sender, address l2Sender);

  /* ============ Setup ============ */

  function setUp() public {
    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    optimismFork = vm.createFork(vm.rpcUrl("optimism"));
  }

  function deployRelayer() public {
    vm.selectFork(mainnetFork);

    relayer = new CrossChainRelayerOptimism(
      ICrossDomainMessenger(proxyOVML1CrossDomainMessenger),
      maxGasLimit
    );

    vm.makePersistent(address(relayer));
  }

  function deployExecutor() public {
    vm.selectFork(optimismFork);

    executor = new CrossChainExecutorOptimism(ICrossDomainMessenger(l2CrossDomainMessenger));

    vm.makePersistent(address(executor));
  }

  function deployGreeter() public {
    vm.selectFork(optimismFork);

    greeter = new Greeter(address(executor), l2Greeting);

    vm.makePersistent(address(greeter));
  }

  function deployAll() public {
    deployRelayer();
    deployExecutor();
    deployGreeter();
  }

  function setExecutor() public {
    vm.selectFork(mainnetFork);
    relayer.setExecutor(executor);
  }

  function setRelayer() public {
    vm.selectFork(optimismFork);
    executor.setRelayer(relayer);
  }

  function setAll() public {
    setExecutor();
    setRelayer();
  }

  /* ============ Tests ============ */

  function testRelayer() public {
    deployRelayer();
    deployExecutor();
    setExecutor();

    assertEq(address(relayer.crossDomainMessenger()), proxyOVML1CrossDomainMessenger);
    assertEq(address(relayer.executor()), address(executor));
  }

  function testExecutor() public {
    deployRelayer();
    deployExecutor();
    setRelayer();

    assertEq(address(executor.crossDomainMessenger()), l2CrossDomainMessenger);
    assertEq(address(executor.relayer()), address(relayer));
  }

  function testGreeter() public {
    deployExecutor();
    deployGreeter();

    assertEq(greeter.greeting(), l2Greeting);
  }

  /* ============ relayCalls ============ */
  function testRelayCalls() public {
    deployAll();
    setAll();

    vm.selectFork(mainnetFork);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.expectEmit(true, true, true, true, address(relayer));

    emit RelayedCalls(nonce, address(this), _calls, 200000);

    uint256 _nonce = relayer.relayCalls(_calls, 200000);

    assertEq(_nonce, nonce);
  }

  /* ============ executeCalls ============ */

  function testExecuteCalls() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    assertEq(greeter.greet(), l2Greeting);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    L2CrossDomainMessenger l2Bridge = L2CrossDomainMessenger(l2CrossDomainMessenger);

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(proxyOVML1CrossDomainMessenger));

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, nonce, address(this), address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedCalls(relayer, nonce);

    l2Bridge.relayMessage(
      address(executor),
      address(relayer),
      abi.encodeWithSignature(
        "executeCalls(uint256,address,(address,bytes)[])",
        nonce,
        address(this),
        _calls
      ),
      l2Bridge.messageNonce() + 1
    );

    assertEq(greeter.greet(), l1Greeting);
  }

  function testGasLimitTooHigh() public {
    deployAll();
    setAll();

    vm.selectFork(mainnetFork);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.expectRevert(
      abi.encodeWithSelector(ICrossChainRelayer.GasLimitTooHigh.selector, 2000000, maxGasLimit)
    );

    relayer.relayCalls(_calls, 2000000);
  }

  function testIsAuthorized() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.expectRevert(bytes("Executor/sender-unauthorized"));

    executor.executeCalls(nonce, address(this), _calls);
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
