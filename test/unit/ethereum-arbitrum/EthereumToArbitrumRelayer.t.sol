// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "forge-std/Test.sol";

import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { CrossChainRelayerArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumRelayer.sol";
import { CrossChainExecutorArbitrum } from "../../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import { ICrossChainRelayer } from "../../../src/interfaces/ICrossChainRelayer.sol";
import "../../../src/libraries/CallLib.sol";

import { Greeter } from "../../contracts/Greeter.sol";
import { ArbInbox } from "../../contracts/mock/ArbInbox.sol";

contract CrossChainRelayerArbitrumUnitTest is Test {
  ArbInbox public inbox = new ArbInbox();
  CrossChainExecutorArbitrum public executor =
    CrossChainExecutorArbitrum(0x77E395E2bfCE67C718C8Ab812c86328EaE356f07);
  Greeter public greeter = Greeter(0x720003dC4EA5aCDA0204823B98E014f095E667f8);

  address public sender = 0xa3a935315931A09A4e9B8A865517Cc18923497Ad;
  address public attacker = 0xdBdDa361Db11Adf8A51dab8a511a8ee89128E89A;

  uint256 public gasLimit = 1000000;

  uint256 public maxSubmissionCost = 1 ether;
  uint256 public gasPriceBid = 500;
  uint256 public nonce = 1;

  string public l1Greeting = "Hello from L1";

  CrossChainRelayerArbitrum public relayer;
  CallLib.Call[] public calls;

  /* ============ Events to test ============ */
  event RelayedCalls(
    uint256 indexed nonce,
    address indexed sender,
    CallLib.Call[] calls,
    uint256 gasLimit
  );

  event ProcessedCalls(uint256 indexed nonce, address indexed sender, uint256 indexed ticketId);

  /* ============ Setup ============ */
  function setUp() public {
    relayer = new CrossChainRelayerArbitrum(inbox);

    calls.push(
      CallLib.Call({
        target: address(greeter),
        data: abi.encodeWithSignature("setGreeting(string)", l1Greeting)
      })
    );
  }

  function setExecutor() public {
    relayer.setExecutor(executor);
  }

  /* ============ Constructor ============ */
  function testConstructor() public {
    assertEq(address(relayer.inbox()), address(inbox));
  }

  function testConstructorInboxFail() public {
    vm.expectRevert(bytes("Relayer/inbox-not-zero-address"));
    relayer = new CrossChainRelayerArbitrum(IInbox(address(0)));
  }

  /* ============ relayCalls ============ */
  function testRelayCalls() public {
    setExecutor();

    vm.expectEmit(true, true, true, true, address(relayer));
    emit RelayedCalls(nonce, address(this), calls, gasLimit);

    uint256 _nonce = relayer.relayCalls(calls, gasLimit);
    assertEq(_nonce, nonce);

    bytes32 txHash = relayer.getTxHash(nonce, calls, address(this), gasLimit);
    assertTrue(relayer.relayed(txHash));
  }

  /* ============ processCalls ============ */

  function testProcessCalls() public {
    setExecutor();

    uint256 _nonce = relayer.relayCalls(calls, gasLimit);
    assertEq(_nonce, nonce);

    vm.expectEmit(true, true, true, true, address(relayer));

    uint256 _randomNumber = inbox.generateRandomNumber();
    emit ProcessedCalls(_nonce, address(this), _randomNumber);

    uint256 _ticketId = relayer.processCalls(
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

    vm.expectRevert(bytes("Relayer/calls-not-relayed"));
    relayer.processCalls(
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
    uint256 _nonce = relayer.relayCalls(calls, gasLimit);

    vm.expectRevert(bytes("Relayer/executor-not-set"));

    relayer.processCalls(
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

    uint256 _nonce = relayer.relayCalls(calls, gasLimit);

    vm.expectRevert(bytes("Relayer/refund-address-not-zero"));

    relayer.processCalls(
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
    bytes32 txHash = relayer.getTxHash(nonce, calls, sender, gasLimit);

    bytes32 txHashMatch = keccak256(abi.encode(address(relayer), nonce, calls, sender, gasLimit));

    assertEq(txHash, txHashMatch);
  }

  function testGetTxHashFail() public {
    bytes32 txHash = relayer.getTxHash(nonce, calls, sender, gasLimit);

    bytes32 txHashForged = keccak256(
      abi.encode(address(relayer), nonce, calls, attacker, gasLimit)
    );

    assertTrue(txHash != txHashForged);
  }

  /* ============ Setters ============ */
  function testSetExecutor() public {
    setExecutor();
    assertEq(address(executor), address(relayer.executor()));
  }

  function testSetExecutorFail() public {
    setExecutor();

    vm.expectRevert(bytes("Relayer/executor-already-set"));
    relayer.setExecutor(CrossChainExecutorArbitrum(address(0)));
  }
}
