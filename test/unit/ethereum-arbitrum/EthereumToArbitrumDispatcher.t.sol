// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { MessageDispatcherArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";
import { MessageExecutorArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import { IMessageDispatcher } from "../../../src/interfaces/IMessageDispatcher.sol";
import "../../../src/libraries/CallLib.sol";

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
  CallLib.Call[] public calls;

  /* ============ Events to test ============ */
  event RelayedCalls(
    uint256 indexed nonce,
    address indexed from,
    CallLib.Call[] calls,
    uint256 toChainId
  );

  event ProcessedCalls(uint256 indexed nonce, address indexed sender, uint256 indexed ticketId);

  /* ============ Setup ============ */
  function setUp() public {
    dispatcher = new MessageDispatcherArbitrum(inbox, toChainId);

    calls.push(
      CallLib.Call({
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
    vm.expectRevert(bytes("Dispatcher/inbox-not-zero-address"));
    dispatcher = new MessageDispatcherArbitrum(IInbox(address(0)), toChainId);
  }

  function testConstructorToChainIdFail() public {
    vm.expectRevert(bytes("Dispatcher/chainId-not-zero"));
    dispatcher = new MessageDispatcherArbitrum(inbox, 0);
  }

  /* ============ dispatchMessages ============ */
  function testRelayCalls() public {
    setExecutor();

    vm.expectEmit(true, true, true, true, address(dispatcher));
    emit RelayedCalls(nonce, address(this), calls, toChainId);

    uint256 _nonce = dispatcher.dispatchMessages(calls);
    assertEq(_nonce, nonce);

    bytes32 txHash = dispatcher.getTxHash(nonce, calls, address(this));
    assertTrue(dispatcher.relayed(txHash));
  }

  /* ============ processCalls ============ */

  function testProcessCalls() public {
    setExecutor();

    uint256 _nonce = dispatcher.dispatchMessages(calls);
    assertEq(_nonce, nonce);

    vm.expectEmit(true, true, true, true, address(dispatcher));

    uint256 _randomNumber = inbox.generateRandomNumber();
    emit ProcessedCalls(_nonce, address(this), _randomNumber);

    uint256 _ticketId = dispatcher.processCalls(
      _nonce,
      calls,
      address(this),
      msg.sender,
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );

    assertEq(_ticketId, _randomNumber);
  }

  function testCallsNotRelayed() public {
    setExecutor();

    vm.expectRevert(bytes("Dispatcher/calls-not-relayed"));
    dispatcher.processCalls(
      nonce,
      calls,
      address(this),
      msg.sender,
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );
  }

  function testExecutorNotSet() public {
    uint256 _nonce = dispatcher.dispatchMessages(calls);

    vm.expectRevert(bytes("Dispatcher/executor-not-set"));

    dispatcher.processCalls(
      _nonce,
      calls,
      address(this),
      msg.sender,
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );
  }

  function testRefundAddressNotZero() public {
    setExecutor();

    uint256 _nonce = dispatcher.dispatchMessages(calls);

    vm.expectRevert(bytes("Dispatcher/refund-address-not-zero"));

    dispatcher.processCalls(
      _nonce,
      calls,
      address(this),
      address(0),
      gasLimit,
      maxSubmissionCost,
      gasPriceBid
    );
  }

  /* ============ Getters ============ */
  function testGetTxHash() public {
    bytes32 txHash = dispatcher.getTxHash(nonce, calls, from);

    bytes32 txHashMatch = keccak256(abi.encode(address(dispatcher), nonce, calls, from));

    assertEq(txHash, txHashMatch);
  }

  function testGetTxHashFail() public {
    bytes32 txHash = dispatcher.getTxHash(nonce, calls, from);

    bytes32 txHashForged = keccak256(abi.encode(address(dispatcher), nonce, calls, attacker));

    assertTrue(txHash != txHashForged);
  }

  /* ============ Setters ============ */
  function testSetExecutor() public {
    setExecutor();
    assertEq(address(executor), address(dispatcher.executor()));
  }

  function testSetExecutorFail() public {
    setExecutor();

    vm.expectRevert(bytes("Dispatcher/executor-already-set"));
    dispatcher.setExecutor(MessageExecutorArbitrum(address(0)));
  }
}
