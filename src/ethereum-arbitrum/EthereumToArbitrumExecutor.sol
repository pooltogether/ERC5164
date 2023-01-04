// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { AddressAliasHelper } from "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";

import "../interfaces/IMessageExecutor.sol";
import "../libraries/MessageLib.sol";

/**
 * @title MessageExecutorArbitrum contract
 * @notice The MessageExecutorArbitrum contract executes messages from the Ethereum chain.
 *         These messages are sent by the `MessageDispatcherArbitrum` contract which lives on the Ethereum chain.
 */
contract MessageExecutorArbitrum is IMessageExecutor {
  /* ============ Variables ============ */

  /// @notice Address of the dispatcher contract on the Ethereum chain.
  IMessageDispatcher public dispatcher;

  /**
   * @notice ID uniquely identifying the messages that were executed.
   *         messageId => boolean
   * @dev Ensure that messages cannot be replayed once they have been executed.
   */
  mapping(bytes32 => bool) public executed;

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

    emit ExecutedMessage(_fromChainId, _dispatcher, _messageId);
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

    emit ExecutedMessageBatch(_fromChainId, _dispatcher, _messageId);
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
   * @notice Check that the message came from the `dispatcher` on the Ethereum chain.
   * @dev We check that the sender is the L1 contract's L2 alias.
   * @param _dispatcher Address of the dispatcher on the Ethereum chain
   */
  function _isAuthorized(IMessageDispatcher _dispatcher) internal view {
    require(
      msg.sender == AddressAliasHelper.applyL1ToL2Alias(address(_dispatcher)),
      "Executor/sender-unauthorized"
    );
  }
}
