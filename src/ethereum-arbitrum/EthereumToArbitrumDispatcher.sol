// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { IMessageExecutor } from "../interfaces/IMessageExecutor.sol";
import { IMessageDispatcher } from "../interfaces/IMessageDispatcher.sol";
import "../libraries/CallLib.sol";

/**
 * @title MessageDispatcherArbitrum contract
 * @notice The MessageDispatcherArbitrum contract allows a user or contract to send messages from Ethereum to Arbitrum.
 *         It lives on the Ethereum chain and communicates with the `MessageExecutorArbitrum` contract on the Arbitrum chain.
 */
contract MessageDispatcherArbitrum is IMessageDispatcher {
  /* ============ Events ============ */

  /**
   * @notice Emitted once a message has been processed and put in the Arbitrum inbox.
   * @dev Using the `ticketId`, this message can be reexecuted for some fixed amount of time if it reverts.
   * @param nonce Nonce to uniquely identify the batch of calls
   * @param sender Address who processed the calls
   * @param ticketId Id of the newly created retryable ticket
   */
  event ProcessedCalls(uint256 indexed nonce, address indexed sender, uint256 indexed ticketId);

  /* ============ Variables ============ */

  /// @notice Address of the Arbitrum inbox on the Ethereum chain.
  IInbox public immutable inbox;

  /// @notice Address of the executor contract on the Arbitrum chain.
  IMessageExecutor public executor;

  /// @notice Nonce to uniquely identify each batch of calls.
  uint256 public nonce;

  /// @notice ID of the chain receiving the relayed calls. i.e.: 42161 for Mainnet, 421613 for Goerli.
  uint256 internal toChainId;

  /**
   * @notice Hash of transactions that were relayed in `dispatchMessages`.
   *         txHash => boolean
   * @dev Ensure that messages passed to `processCalls` have been relayed first.
   */
  mapping(bytes32 => bool) public relayed;

  /* ============ Constructor ============ */

  /**
   * @notice MessageDispatcher constructor.
   * @param _inbox Address of the Arbitrum inbox on Ethereum
   * @param _toChainId ID of the chain receiving the relayed calls
   */
  constructor(IInbox _inbox, uint256 _toChainId) {
    require(address(_inbox) != address(0), "Dispatcher/inbox-not-zero-address");
    require(_toChainId != 0, "Dispatcher/chainId-not-zero");

    inbox = _inbox;
    toChainId = _toChainId;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc IMessageDispatcher
  function dispatchMessage(CallLib.Call calldata _call) external returns (uint256) {
    CallLib.Call[] memory _calls = new CallLib.Call[](1);
    _calls[0] = _call;

    return _dispatchMessages(_calls);
  }

  /// @inheritdoc IMessageDispatcher
  function dispatchMessages(CallLib.Call[] calldata _calls) external returns (uint256) {
    return _dispatchMessages(_calls);
  }

  /**
   * @notice Process calls that have been relayed.
   * @dev The transaction hash must match the one stored in the `relayed` mapping.
   * @dev `_from` is passed as `callValueRefundAddress` cause this address can cancel the retryably ticket.
   * @dev We store `_data` in memory to avoid a stack too deep error.
   * @param _nonce Nonce of the batch of calls to process
   * @param _calls Array of calls being processed
   * @param _from Address who relayed the `_calls`
   * @param _refundAddress Address that will receive the `excessFeeRefund` amount if any
   * @param _gasLimit Maximum amount of gas required for the `_calls` to be executed
   * @param _maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param _gasPriceBid Gas price bid for L2 execution
   * @return uint256 Id of the retryable ticket that was created
   */
  function processCalls(
    uint256 _nonce,
    CallLib.Call[] calldata _calls,
    address _from,
    address _refundAddress,
    uint256 _gasLimit,
    uint256 _maxSubmissionCost,
    uint256 _gasPriceBid
  ) external payable returns (uint256) {
    require(relayed[_getTxHash(_nonce, _calls, _from)], "Dispatcher/calls-not-relayed");

    address _executorAddress = address(executor);
    require(_executorAddress != address(0), "Dispatcher/executor-not-set");

    require(_refundAddress != address(0), "Dispatcher/refund-address-not-zero");

    bytes memory _data = abi.encodeWithSelector(
      IMessageExecutor.executeCalls.selector,
      _nonce,
      _from,
      _calls
    );

    uint256 _ticketID = inbox.createRetryableTicket{ value: msg.value }(
      _executorAddress,
      0,
      _maxSubmissionCost,
      _refundAddress,
      _from,
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
  function setExecutor(IMessageExecutor _executor) external {
    require(address(executor) == address(0), "Dispatcher/executor-already-set");
    executor = _executor;
  }

  /**
   * @notice Get transaction hash.
   * @dev The transaction hash is used to ensure that only calls that were relayed are processed.
   * @param _nonce Nonce uniquely identifying the batch of calls that were relayed
   * @param _calls Array of calls that were relayed
   * @param _from Address who relayed the calls
   * @return bytes32 Transaction hash
   */
  function getTxHash(
    uint256 _nonce,
    CallLib.Call[] calldata _calls,
    address _from
  ) external view returns (bytes32) {
    return _getTxHash(_nonce, _calls, _from);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Get transaction hash.
   * @dev The transaction hash is used to ensure that only calls that were relayed are processed.
   * @param _nonce Nonce uniquely identifying the batch of calls that were relayed
   * @param _calls Array of calls that were relayed
   * @param _from Address who relayed the calls
   * @return bytes32 Transaction hash
   */
  function _getTxHash(
    uint256 _nonce,
    CallLib.Call[] memory _calls,
    address _from
  ) internal view returns (bytes32) {
    return keccak256(abi.encode(address(this), _nonce, _calls, _from));
  }

  /**
   * @notice Relay calls to the receiving chain.
   * @param _calls Array of calls being relayed
   * @return uint256 Nonce to uniquely identify the batch of calls
   */
  function _dispatchMessages(CallLib.Call[] memory _calls) internal returns (uint256) {
    unchecked {
      nonce++;
    }

    uint256 _nonce = nonce;

    relayed[_getTxHash(_nonce, _calls, msg.sender)] = true;

    emit RelayedCalls(_nonce, msg.sender, _calls, toChainId);

    return _nonce;
  }
}
