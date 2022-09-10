// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { L2CrossDomainMessenger } from "@eth-optimism/contracts/L2/messaging/L2CrossDomainMessenger.sol";
import { AddressAliasHelper } from "@eth-optimism/contracts/standards/AddressAliasHelper.sol";

import { ICrossChainRelayer } from "../src/interfaces/ICrossChainRelayer.sol";
import { ICrossChainExecutor } from "../src/interfaces/ICrossChainExecutor.sol";
import "../src/relayers/CrossChainRelayerOptimism.sol";
import "../src/executors/CrossChainExecutorOptimism.sol";
import "./Greeter.sol";

contract EthereumToOptimismForkTest is Test {
  uint256 public mainnetFork;
  uint256 public optimismFork;

  CrossChainRelayerOptimism public relayer;
  CrossChainExecutorOptimism public executor;
  Greeter public greeter;

  address public proxyOVML1CrossDomainMessenger = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;

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

    greeter = new Greeter(address(executor), greeterL2Greeting);

    vm.makePersistent(address(greeter));
  }

  function deployAll() public {
    deployRelayer();
    deployExecutor();
    deployGreeter();
  }

  /* ============ Tests ============ */

  function testRelayer() public {
    deployRelayer();
    assertEq(address(relayer.bridge()), proxyOVML1CrossDomainMessenger);
  }

  function testExecutor() public {
    deployExecutor();
    assertEq(address(executor.bridge()), l2CrossDomainMessenger);
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

    emit RelayedCalls(nonce, address(this), executor, _calls, 200000);

    relayer.relayCalls(executor, _calls, 200000);
  }

  function testExecuteCalls() public {
    deployAll();

    vm.selectFork(optimismFork);

    assertEq(greeter.greet(), greeterL2Greeting);

    ICrossChainExecutor.Call[] memory _calls = new ICrossChainExecutor.Call[](1);

    _calls[0] = ICrossChainExecutor.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", greeterL1Greeting)
    });

    L2CrossDomainMessenger l2Bridge = L2CrossDomainMessenger(l2CrossDomainMessenger);

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(proxyOVML1CrossDomainMessenger));

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(greeterL1Greeting, address(this), address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedCalls(relayer, nonce, l2CrossDomainMessenger, _calls);

    l2Bridge.relayMessage(
      address(executor),
      address(relayer),
      abi.encodeWithSignature(
        "executeCalls(address,uint256,address,(address,bytes)[])",
        address(relayer),
        nonce,
        address(this),
        _calls
      ),
      l2Bridge.messageNonce() + 1
    );

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
        CrossChainRelayerOptimism.GasLimitTooHigh.selector,
        2000000,
        maxGasLimit
      )
    );

    relayer.relayCalls(executor, _calls, 2000000);
  }

  function testIsAuthorized() public {
    deployAll();

    vm.selectFork(optimismFork);

    ICrossChainExecutor.Call[] memory _calls = new ICrossChainExecutor.Call[](1);

    _calls[0] = ICrossChainExecutor.Call({
      target: address(greeter),
      data: abi.encodeWithSignature("setGreeting(string)", greeterL1Greeting)
    });

    vm.expectRevert(bytes("Executor/caller-unauthorized"));

    executor.executeCalls(relayer, nonce, address(this), _calls);
  }

  function testSetGreetingError() public {
    deployAll();

    vm.selectFork(optimismFork);

    vm.expectRevert(bytes("Greeter/caller-not-executor"));

    greeter.setGreeting(greeterL2Greeting);
  }
}
