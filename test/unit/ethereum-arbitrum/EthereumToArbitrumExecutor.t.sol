// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { AddressAliasHelper } from "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";
import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { IMessageDispatcher } from "../../../src/interfaces/IMessageDispatcher.sol";
import { MessageExecutorArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import { MessageDispatcherArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";
import "../../../src/libraries/CallLib.sol";

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

  CallLib.Call[] public calls;
  MessageExecutorArbitrum public executor;
  Greeter public greeter;

  /* ============ Events to test ============ */

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
    executor = new MessageExecutorArbitrum();
    greeter = new Greeter(address(executor), "Hello from L2");
  }

  function pushCalls(address _to) public {
    calls.push(
      CallLib.Call({ to: _to, data: abi.encodeWithSignature("setGreeting(string)", l1Greeting) })
    );
  }

  function setDispatcher() public {
    executor.setDispatcher(dispatcher);
  }

  /* ============ executeCalls ============ */

  function testExecuteCalls() public {
    setDispatcher();
    pushCalls(address(greeter));

    vm.startPrank(dispatcherAlias);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(l1Greeting, nonce, from, fromChainId, address(executor));

    vm.expectEmit(true, true, true, true, address(executor));
    emit CallLib.CallSuccess(1, 0, bytes(""));

    vm.expectEmit(true, true, true, true, address(executor));
    emit ExecutedCalls(fromChainId, dispatcher, nonce);

    executor.executeCalls(calls, nonce, from, fromChainId);

    assertTrue(executor.executed(nonce));
  }

  function testExecuteCallsAlreadyExecuted() public {
    setDispatcher();
    pushCalls(address(greeter));

    vm.startPrank(dispatcherAlias);
    executor.executeCalls(calls, nonce, from, fromChainId);

    vm.expectRevert(abi.encodeWithSelector(CallLib.CallsAlreadyExecuted.selector, nonce));
    executor.executeCalls(calls, nonce, from, fromChainId);
  }

  function testExecuteCallsFailed() public {
    setDispatcher();
    pushCalls(address(this));

    vm.startPrank(dispatcherAlias);

    vm.expectEmit(true, true, true, true, address(executor));
    emit CallLib.CallFailure(1, 0, bytes(""));

    vm.expectRevert(
      abi.encodeWithSelector(
        MessageExecutorArbitrum.ExecuteCallsFailed.selector,
        fromChainId,
        address(dispatcher),
        nonce
      )
    );

    executor.executeCalls(calls, nonce, from, fromChainId);
  }

  function testExecuteCallsUnauthorized() public {
    setDispatcher();
    pushCalls(address(greeter));

    vm.expectRevert(bytes("Executor/sender-unauthorized"));
    executor.executeCalls(calls, nonce, from, fromChainId);
  }

  function testExecuteCallsToNotZeroAddress() public {
    setDispatcher();
    pushCalls(address(0));

    vm.startPrank(dispatcherAlias);

    vm.expectRevert(bytes("CallLib/no-contract-at-to"));
    executor.executeCalls(calls, nonce, from, fromChainId);
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
