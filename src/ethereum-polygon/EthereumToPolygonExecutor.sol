// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { FxBaseChildTunnel } from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseChildTunnel.sol";

import "../libraries/MessageLib.sol";

/**
 * @title MessageExecutorPolygon contract
 * @notice The MessageExecutorPolygon contract executes messages from the Ethereum chain.
 *         These messages are sent by the `MessageDispatcherPolygon` contract which lives on the Ethereum chain.
 */
contract MessageExecutorPolygon is FxBaseChildTunnel {
  /* ============ Events ============ */

  /**
   * @notice Emitted when a message has successfully been executed.
   * @param fromChainId ID of the chain that dispatched the message
   * @param messageId ID uniquely identifying the message that was executed
   */
  event MessageIdExecuted(uint256 indexed fromChainId, bytes32 indexed messageId);

  /* ============ Variables ============ */

  /**
   * @notice ID uniquely identifying the messages that were executed.
   *         messageId => boolean
   * @dev Ensure that messages cannot be replayed once they have been executed.
   */
  mapping(bytes32 => bool) public executed;

  /* ============ Constructor ============ */

  /**
   * @notice MessageExecutorPolygon constructor.
   * @param _fxChild Address of the FxChild contract on the Polygon chain
   */
  constructor(address _fxChild) FxBaseChildTunnel(_fxChild) {}

  /* ============ Internal Functions ============ */

  /// @inheritdoc FxBaseChildTunnel
  function _processMessageFromRoot(
    uint256, /* _stateId */
    address _sender,
    bytes memory _data
  ) internal override validateSender(_sender) {
    (
      MessageLib.Message[] memory _messages,
      bytes32 _messageId,
      uint256 _fromChainId,
      address _from
    ) = abi.decode(_data, (MessageLib.Message[], bytes32, uint256, address));

    bool _executedMessageId = executed[_messageId];
    executed[_messageId] = true;

    if (_messages.length == 1) {
      MessageLib.Message memory _message = _messages[0];
      MessageLib.executeMessage(
        _message.to,
        _message.data,
        _messageId,
        _fromChainId,
        _from,
        _executedMessageId
      );

      emit MessageIdExecuted(_fromChainId, _messageId);
    } else {
      MessageLib.executeMessageBatch(
        _messages,
        _messageId,
        _fromChainId,
        _from,
        _executedMessageId
      );

      emit MessageIdExecuted(_fromChainId, _messageId);
    }
  }
}
