// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../interfaces/IMessageExecutor.sol";
import "../libraries/MessageLib.sol";

/**
 * @title MessageExecutorOptimism contract
 * @notice The MessageExecutorOptimism contract executes messages from the Ethereum chain.
 *         These messages are sent by the `MessageDispatcherOptimism` contract which lives on the Ethereum chain.
 */
contract MessageExecutorOptimism is IMessageExecutor {
  /* ============ Variables ============ */

  /// @notice Address of the Optimism cross domain messenger on the Optimism chain.
  ICrossDomainMessenger public immutable crossDomainMessenger;

  /// @notice Address of the dispatcher contract on the Ethereum chain.
  IMessageDispatcher public dispatcher;

  /**
   * @notice Mapping to uniquely identify the messages that were executed
   *         messageId => boolean
   * @dev Ensure that messages cannot be replayed once they have been executed.
   */
  mapping(bytes32 => bool) public executed;

  /* ============ Constructor ============ */

  /**
   * @notice MessageExecutorOptimism constructor.
   * @param _crossDomainMessenger Address of the Optimism cross domain messenger on the Optimism chain
   */
  constructor(ICrossDomainMessenger _crossDomainMessenger) {
    require(address(_crossDomainMessenger) != address(0), "Executor/CDM-not-zero-address");
    crossDomainMessenger = _crossDomainMessenger;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc IMessageExecutor
  function executeMessage(
    address _to,
    bytes calldata _data,
    bytes32 _messageId,
    uint256 _fromChainId,
    address _from
  ) external {
    IMessageDispatcher _dispatcher = dispatcher;
    _isAuthorized(_dispatcher);

    bool _executedMessageId = executed[_messageId];
    executed[_messageId] = true;

    MessageLib.executeMessage(_to, _data, _messageId, _fromChainId, _from, _executedMessageId);

    emit MessageIdExecuted(_fromChainId, _messageId);
  }

  /// @inheritdoc IMessageExecutor
  function executeMessageBatch(
    MessageLib.Message[] calldata _messages,
    bytes32 _messageId,
    uint256 _fromChainId,
    address _from
  ) external {
    IMessageDispatcher _dispatcher = dispatcher;
    _isAuthorized(_dispatcher);

    bool _executedMessageId = executed[_messageId];
    executed[_messageId] = true;

    MessageLib.executeMessageBatch(_messages, _messageId, _fromChainId, _from, _executedMessageId);

    emit MessageIdExecuted(_fromChainId, _messageId);
  }

  /**
   * @notice Set dispatcher contract address.
   * @dev Will revert if it has already been set.
   * @param _dispatcher Address of the dispatcher contract on the Ethereum chain
   */
  function setDispatcher(IMessageDispatcher _dispatcher) external {
    require(address(dispatcher) == address(0), "Executor/dispatcher-already-set");
    dispatcher = _dispatcher;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Check if sender is authorized to message `executeMessageBatch`.
   * @param _dispatcher Address of the dispatcher on the Ethereum chain
   */
  function _isAuthorized(IMessageDispatcher _dispatcher) internal view {
    ICrossDomainMessenger _crossDomainMessenger = crossDomainMessenger;

    require(
      msg.sender == address(_crossDomainMessenger) &&
        _crossDomainMessenger.xDomainMessageSender() == address(_dispatcher),
      "Executor/sender-unauthorized"
    );
  }
}
