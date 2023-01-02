// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { ICrossChainExecutor } from "../interfaces/ICrossChainExecutor.sol";
import { ICrossChainRelayer } from "../interfaces/ICrossChainRelayer.sol";
import "../libraries/CallLib.sol";

/**
 * @title CrossChainRelayerArbitrum contract
 * @notice The CrossChainRelayerArbitrum contract allows a user or contract to send messages from Ethereum to Arbitrum.
 *         It lives on the Ethereum chain and communicates with the `CrossChainExecutorArbitrum` contract on the Arbitrum chain.
 */
contract CrossChainRelayerArbitrum is ICrossChainRelayer {
  /* ============ Events ============ */

  /**
   * @notice Emitted once a message has been processed and put in the Arbitrum inbox.
   * @dev Using the `ticketId`, this message can be reexecuted for some fixed amount of time if it reverts.
   * @param nonce Nonce to uniquely idenfity the batch of calls
   * @param sender Address who processed the calls
   * @param ticketId Id of the newly created retryable ticket
   */
  event ProcessedCalls(uint256 indexed nonce, address indexed sender, uint256 indexed ticketId);

  /* ============ Variables ============ */

  /// @notice Address of the Arbitrum inbox on the Ethereum chain.
  IInbox public immutable inbox;

  /// @notice Address of the executor contract on the Arbitrum chain.
  ICrossChainExecutor public executor;

  /// @notice Nonce to uniquely idenfity each batch of calls.
  uint256 public nonce;

  /**
   * @notice Hash of transactions that were relayed in `relayCalls`.
   *         txHash => boolean
   * @dev Ensure that messages passed to `processCalls` have been relayed first.
   */
  mapping(bytes32 => bool) public relayed;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainRelayer constructor.
   * @param _inbox Address of the Arbitrum inbox on Ethereum
   */
  constructor(IInbox _inbox) {
    require(address(_inbox) != address(0), "Relayer/inbox-not-zero-address");
    inbox = _inbox;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainRelayer
  function relayCalls(CallLib.Call[] calldata _calls, uint256 _gasLimit)
    external
    returns (uint256)
  {
    unchecked {
      nonce++;
    }

    uint256 _nonce = nonce;

    relayed[_getTxHash(_nonce, _calls, msg.sender, _gasLimit)] = true;

    emit RelayedCalls(_nonce, msg.sender, _calls, _gasLimit);

    return _nonce;
  }

  /**
   * @notice Process calls that have been relayed.
   * @dev The transaction hash must match the one stored in the `relayed` mapping.
   * @dev `_sender` is passed as `callValueRefundAddress` cause this address can cancel the retryably ticket.
   * @dev We store `_data` in memory to avoid a stack too deep error.
   * @param _nonce Nonce of the batch of calls to process
   * @param _calls Array of calls being processed
   * @param _sender Address who relayed the `_calls`
   * @param _refundAddress Address that will receive the `excessFeeRefund` amount if any
   * @param _gasLimit Maximum amount of gas required for the `_calls` to be executed
   * @param _maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param _gasPriceBid Gas price bid for L2 execution
   * @return uint256 Id of the retryable ticket that was created
   */
  function processCalls(
    uint256 _nonce,
    CallLib.Call[] calldata _calls,
    address _sender,
    address _refundAddress,
    uint256 _gasLimit,
    uint256 _maxSubmissionCost,
    uint256 _gasPriceBid
  ) external payable returns (uint256) {
    require(relayed[_getTxHash(_nonce, _calls, _sender, _gasLimit)], "Relayer/calls-not-relayed");

    address _executorAddress = address(executor);
    require(_executorAddress != address(0), "Relayer/executor-not-set");

    require(_refundAddress != address(0), "Relayer/refund-address-not-zero");

    bytes memory _data = abi.encodeWithSelector(
      ICrossChainExecutor.executeCalls.selector,
      _nonce,
      _sender,
      _calls
    );

    uint256 _ticketID = inbox.createRetryableTicket{ value: msg.value }(
      _executorAddress,
      0,
      _maxSubmissionCost,
      _refundAddress,
      _sender,
      _gasLimit,
      _gasPriceBid,
      _data
    );

    emit ProcessedCalls(_nonce, msg.sender, _ticketID);

    return _ticketID;
  }

  /**
   * @notice Set executor contract address.
   * @dev Will revert if it has already been set.
   * @param _executor Address of the executor contract on the Arbitrum chain
   */
  function setExecutor(ICrossChainExecutor _executor) external {
    require(address(executor) == address(0), "Relayer/executor-already-set");
    executor = _executor;
  }

  /**
   * @notice Get transaction hash.
   * @dev The transaction hash is used to ensure that only calls that were relayed are processed.
   * @param _nonce Nonce uniquely identifying the batch of calls that were relayed
   * @param _calls Array of calls that were relayed
   * @param _sender Address who relayed the calls
   * @param _gasLimit Maximum amount of gas that will be consumed by the calls
   * @return bytes32 Transaction hash
   */
  function getTxHash(
    uint256 _nonce,
    CallLib.Call[] calldata _calls,
    address _sender,
    uint256 _gasLimit
  ) external view returns (bytes32) {
    return _getTxHash(_nonce, _calls, _sender, _gasLimit);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Get transaction hash.
   * @dev The transaction hash is used to ensure that only calls that were relayed are processed.
   * @param _nonce Nonce uniquely identifying the batch of calls that were relayed
   * @param _calls Array of calls that were relayed
   * @param _sender Address who relayed the calls
   * @param _gasLimit Maximum amount of gas that will be consumed by the calls
   * @return bytes32 Transaction hash
   */
  function _getTxHash(
    uint256 _nonce,
    CallLib.Call[] calldata _calls,
    address _sender,
    uint256 _gasLimit
  ) internal view returns (bytes32) {
    return keccak256(abi.encode(address(this), _nonce, _calls, _sender, _gasLimit));
  }
}
