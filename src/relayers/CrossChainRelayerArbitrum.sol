// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import "../interfaces/ICrossChainRelayer.sol";

/**
 * @title CrossChainRelayer contract
 * @notice The CrossChainRelayer contract allows a user or contract to send messages to another chain.
 *         It lives on the origin chain and communicates with the `CrossChainExecutor` contract on the receiving chain.
 */
contract CrossChainRelayerArbitrum is ICrossChainRelayer {
  /* ============ Custom Errors ============ */

  /**
   * @notice Custom error emitted if the `gasLimit` passed to `relayCalls`
   *         is greater than the one provided for free on Arbitrum.
   * @param gasLimit Gas limit passed to `relayCalls`
   * @param maxGasLimit Gas limit provided for free on Arbitrum
   */
  error GasLimitTooHigh(uint256 gasLimit, uint256 maxGasLimit);

  /* ============ Events ============ */

  /**
   * @notice Emitted once a message has been processed and put in the Arbitrum inbox.
   *         Using the `ticketId`, this message can be reexecuted for some fixed amount of time if it reverts.
   * @param nonce Id of the message that was sent
   * @param sender Address who processed the calls
   * @param ticketId Id of the newly created retryable ticket
   */
  event ProcessedCalls(uint256 indexed nonce, address indexed sender, uint256 indexed ticketId);

  /* ============ Variables ============ */

  /// @notice Address of the Arbitrum inbox on the origin chain.
  IInbox public immutable inbox;

  /// @notice Address of the executor contract on the receiving chain
  ICrossChainExecutor public executor;

  /// @notice Gas limit provided for free on Arbitrum.
  uint256 public immutable maxGasLimit;

  /// @notice Internal nonce to uniquely idenfity each batch of calls.
  uint256 internal nonce;

  /**
   * @notice Hash of transactions that were relayed in `relayCalls`.
   *         txHash => boolean
   * @dev Ensure that messages passed to `processCalls` have been relayed first.
   */
  mapping(bytes32 => bool) public relayed;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainRelayer constructor.
   * @param _inbox Address of the Arbitrum inbox
   * @param _maxGasLimit Gas limit provided for free on Arbitrum
   */
  constructor(IInbox _inbox, uint256 _maxGasLimit) {
    require(address(_inbox) != address(0), "Relayer/inbox-not-zero-address");
    require(_maxGasLimit > 0, "Relayer/max-gas-limit-gt-zero");

    inbox = _inbox;
    maxGasLimit = _maxGasLimit;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainRelayer
  function relayCalls(Call[] calldata _calls, uint256 _gasLimit)
    external
    payable
    returns (uint256)
  {
    uint256 _maxGasLimit = maxGasLimit;

    if (_gasLimit > _maxGasLimit) {
      revert GasLimitTooHigh(_gasLimit, _maxGasLimit);
    }

    nonce++;

    uint256 _nonce = nonce;

    relayed[_getTxHash(_nonce, _calls, msg.sender, _gasLimit)] = true;

    emit RelayedCalls(_nonce, msg.sender, _calls, _gasLimit);

    return _nonce;
  }

  /**
   * @notice Process calls that have been relayed.
   * @dev The transaction hash must match the one stored in the `relayed` mapping.
   * @dev We store `_data` in memory to avoid a stack too deep error.
   * @param _nonce Nonce of the message to process
   * @param _calls Array of calls being processed
   * @param _sender Address who relayed the `_calls`
   * @param _gasLimit Maximum amount of gas required for the `_calls` to be executed
   * @param _maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param _gasPriceBid Gas price bid for L2 execution
   * @return uint256 Id of the retryable ticket that was created
   */
  function processCalls(
    uint256 _nonce,
    Call[] calldata _calls,
    address _sender,
    uint256 _gasLimit,
    uint256 _maxSubmissionCost,
    uint256 _gasPriceBid
  ) external payable returns (uint256) {
    require(relayed[_getTxHash(_nonce, _calls, _sender, _gasLimit)], "Relayer/calls-not-relayed");

    bytes memory _data = abi.encodeWithSignature(
      "executeCalls(uint256,address,(address,bytes)[])",
      _nonce,
      _sender,
      _calls
    );

    uint256 _ticketID = inbox.createRetryableTicket{ value: msg.value }(
      address(executor),
      0,
      _maxSubmissionCost,
      msg.sender,
      msg.sender,
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
   * @param _executor Address of the executor contract on the receiving chain
   */
  function setExecutor(ICrossChainExecutor _executor) external {
    require(address(executor) == address(0), "Relayer/executor-already-set");
    executor = _executor;
  }

  /**
   * @notice Get transaction hash.
   * @dev The transaction hash is used to ensure that only calls that were relayed are processed.
   * @param _nonce Nonce uniquely identifying the messages that were relayed
   * @param _calls Array of calls that were relayed
   * @param _sender Address who relayed the calls
   * @param _gasLimit Maximum amount of gas that will be consumed by the calls
   * @return bytes32 Transaction hash
   */
  function getTxHash(
    uint256 _nonce,
    Call[] calldata _calls,
    address _sender,
    uint256 _gasLimit
  ) external view returns (bytes32) {
    return _getTxHash(_nonce, _calls, _sender, _gasLimit);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Get transaction hash.
   * @dev The transaction hash is used to ensure that only calls that were relayed are processed.
   * @param _nonce Nonce uniquely identifying the messages that were relayed
   * @param _calls Array of calls that were relayed
   * @param _sender Address who relayed the calls
   * @param _gasLimit Maximum amount of gas that will be consumed by the calls
   * @return bytes32 Transaction hash
   */
  function _getTxHash(
    uint256 _nonce,
    Call[] calldata _calls,
    address _sender,
    uint256 _gasLimit
  ) internal view returns (bytes32) {
    return keccak256(abi.encode(address(this), _nonce, _calls, _sender, _gasLimit));
  }
}
