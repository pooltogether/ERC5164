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
import "../../src/libraries/CallLib.sol";

import "../contracts/Greeter.sol";

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

    assertEq(address(dispatcher.crossDomainMessenger()), proxyOVML1CrossDomainMessenger);
    assertEq(address(dispatcher.executor()), address(executor));
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

  /* ============ dispatchMessages ============ */
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

  function testExecutorNotSet() public {
    deployAll();

    vm.selectFork(mainnetFork);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      to: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.expectRevert(bytes("Dispatcher/executor-not-set"));

    dispatcher.dispatchMessages(_calls);
  }

  /* ============ executeCalls ============ */

  function testExecuteCalls() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    assertEq(greeter.greet(), l2Greeting);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      to: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    L2CrossDomainMessenger l2Bridge = L2CrossDomainMessenger(l2CrossDomainMessenger);

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(proxyOVML1CrossDomainMessenger));

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, nonce, address(this), fromChainId, address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedCalls(fromChainId, dispatcher, nonce);

    l2Bridge.relayMessage(
      address(executor),
      address(dispatcher),
      abi.encodeWithSignature(
        "executeCalls((address,bytes)[],uint256,address,uint256)",
        _calls,
        nonce,
        address(this),
        fromChainId
      ),
      l2Bridge.messageNonce() + 1
    );

    assertEq(greeter.greet(), l1Greeting);
  }

  function testIsAuthorized() public {
    deployAll();
    setAll();

    vm.selectFork(optimismFork);

    CallLib.Call[] memory _calls = new CallLib.Call[](1);

    _calls[0] = CallLib.Call({
      to: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
    });

    vm.expectRevert(bytes("Executor/sender-unauthorized"));

    executor.executeCalls(_calls, nonce, address(this), fromChainId);
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
