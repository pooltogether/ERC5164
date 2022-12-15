// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { AddressAliasHelper } from "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";
import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { ICrossChainRelayer } from "../../../src/interfaces/ICrossChainRelayer.sol";
import { CrossChainExecutorArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import { CrossChainRelayerArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumRelayer.sol";
import "../../../src/libraries/CallLib.sol";

import { Greeter } from "../../contracts/Greeter.sol";

contract CrossChainExecutorArbitrumUnitTest is Test {
  CrossChainRelayerArbitrum public relayer =
    CrossChainRelayerArbitrum(0x77E395E2bfCE67C718C8Ab812c86328EaE356f07);

  address public relayerAlias = AddressAliasHelper.applyL1ToL2Alias(address(relayer));

  address public sender = 0xa3a935315931A09A4e9B8A865517Cc18923497Ad;
  address public attacker = 0xdBdDa361Db11Adf8A51dab8a511a8ee89128E89A;

  uint256 public nonce = 1;

  string public l1Greeting = "Hello from L1";

  CallLib.Call[] public calls;
  CrossChainExecutorArbitrum public executor;
  Greeter public greeter;

  /* ============ Events to test ============ */

  event ExecutedCalls(ICrossChainRelayer indexed relayer, uint256 indexed nonce);

  event SetGreeting(string greeting, uint256 nonce, address l1Sender, address l2Sender);

  /* ============ Setup ============ */

  function setUp() public {
    executor = new CrossChainExecutorArbitrum();
    greeter = new Greeter(address(executor), "Hello from L2");
  }

  function pushCalls(address _target) public {
    calls.push(
      CallLib.Call({
        target: _target,
        data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
      })
    );
  }

  function setRelayer() public {
    executor.setRelayer(relayer);
  }

  /* ============ executeCalls ============ */

  function testExecuteCalls() public {
    setRelayer();
    pushCalls(address(greeter));

    vm.startPrank(relayerAlias);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, nonce, sender, address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit CallLib.CallSuccess(0, bytes(""));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedCalls(relayer, nonce);

    executor.executeCalls(nonce, sender, calls);

    assertTrue(executor.executed(nonce));
  }

  function testExecuteCallsAlreadyExecuted() public {
    setRelayer();
    pushCalls(address(greeter));

    vm.startPrank(relayerAlias);
    executor.executeCalls(nonce, sender, calls);

    vm.expectRevert(abi.encodeWithSelector(CallLib.CallsAlreadyExecuted.selector, nonce));
    executor.executeCalls(nonce, sender, calls);
  }

  function testExecuteCallsFailed() public {
    setRelayer();
    pushCalls(address(this));

    vm.startPrank(relayerAlias);

    vm.expectEmit(true, true, true, true, address(executor));
    emit CallLib.CallFailure(0, bytes(""));

    vm.expectRevert(
      abi.encodeWithSelector(
        CrossChainExecutorArbitrum.ExecuteCallsFailed.selector,
        address(relayer),
        nonce
      )
    );

    executor.executeCalls(nonce, sender, calls);
  }

  function testExecuteCallsUnauthorized() public {
    setRelayer();
    pushCalls(address(greeter));

    vm.expectRevert(bytes("Executor/sender-unauthorized"));
    executor.executeCalls(nonce, sender, calls);
  }

  function testExecuteCallsTargetNotZeroAddress() public {
    setRelayer();
    pushCalls(address(0));

    vm.startPrank(relayerAlias);

    vm.expectRevert(bytes("CallLib/target-not-zero-address"));
    executor.executeCalls(nonce, sender, calls);
  }

  /* ============ Setters ============ */

  function testSetRelayer() public {
    setRelayer();
    assertEq(address(relayer), address(executor.relayer()));
  }

  function testSetRelayerFail() public {
    setRelayer();

    vm.expectRevert(bytes("Executor/relayer-already-set"));
    executor.setRelayer(CrossChainRelayerArbitrum(address(0)));
  }
}
