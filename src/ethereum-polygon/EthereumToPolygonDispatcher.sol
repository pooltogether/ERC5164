// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { FxBaseRootTunnel } from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";

import { IMessageExecutor } from "../interfaces/IMessageExecutor.sol";
import { IMessageDispatcher, ISingleMessageDispatcher } from "../interfaces/ISingleMessageDispatcher.sol";
import { IBatchedMessageDispatcher } from "../interfaces/IBatchedMessageDispatcher.sol";

import "../libraries/MessageLib.sol";

/**
 * @title MessageDispatcherPolygon contract
 * @notice The MessageDispatcherPolygon contract allows a user or contract to send messages from Ethereum to Polygon.
 *         It lives on the Ethereum chain and communicates with the `MessageExecutorPolygon` contract on the Polygon chain.
 */
contract MessageDispatcherPolygon is
  ISingleMessageDispatcher,
  IBatchedMessageDispatcher,
  FxBaseRootTunnel
{
  /* ============ Variables ============ */

  /// @notice Nonce used to compute unique `messageId`s.
  uint256 internal nonce;

  /// @notice ID of the chain receiving the dispatched messages. i.e.: 137 for Mainnet, 80001 for Mumbai.
  uint256 internal immutable toChainId;

  /* ============ Constructor ============ */

  /**
   * @notice MessageDispatcherPolygon constructor.
   * @param _checkpointManager Address of the root chain manager contract on Ethereum
   * @param _fxRoot Address of the state sender contract on Ethereum
   * @param _toChainId ID of the chain receiving the dispatched messages
   */
  constructor(
    address _checkpointManager,
    address _fxRoot,
    uint256 _toChainId
  ) FxBaseRootTunnel(_checkpointManager, _fxRoot) {
    require(_toChainId != 0, "Dispatcher/chainId-not-zero");
    toChainId = _toChainId;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ISingleMessageDispatcher
  function dispatchMessage(
    uint256 _toChainId,
    address _to,
    bytes calldata _data
  ) external returns (bytes32) {
    _checkDispatchParams(_toChainId);

    uint256 _nonce = _incrementNonce();
    bytes32 _messageId = MessageLib.computeMessageId(_nonce, msg.sender, _to, _data);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({ to: _to, data: _data });

    _sendMessageToChild(abi.encode(_messages, _messageId, block.chainid, msg.sender));

    emit MessageDispatched(_messageId, msg.sender, _toChainId, _to, _data);

    return _messageId;
  }

  /// @inheritdoc IBatchedMessageDispatcher
  function dispatchMessageBatch(uint256 _toChainId, MessageLib.Message[] calldata _messages)
    external
    returns (bytes32)
  {
    _checkDispatchParams(_toChainId);

    uint256 _nonce = _incrementNonce();
    bytes32 _messageId = MessageLib.computeMessageBatchId(_nonce, msg.sender, _messages);

    _sendMessageToChild(abi.encode(_messages, _messageId, block.chainid, msg.sender));

    emit MessageBatchDispatched(_messageId, msg.sender, _toChainId, _messages);

    return _messageId;
  }

  /// @inheritdoc IMessageDispatcher
  function getMessageExecutorAddress(uint256 _chainId) external view returns (address) {
    _checkToChainId(_chainId);
    return address(fxChildTunnel);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Check toChainId to ensure messages can be dispatched to this chain.
   * @dev Will revert if `_toChainId` is not supported.
   * @param _toChainId ID of the chain receiving the message
   */
  function _checkToChainId(uint256 _toChainId) internal view {
    require(_toChainId == toChainId, "Dispatcher/chainId-not-supported");
  }

  /**
   * @notice Check dispatch parameters to ensure messages can be dispatched.
   * @dev Will revert if `fxChildTunnel` is not set.
   * @dev Will revert if `_toChainId` is not supported.
   * @param _toChainId ID of the chain receiving the message
   */
  function _checkDispatchParams(uint256 _toChainId) internal view {
    require(address(fxChildTunnel) != address(0), "Dispatcher/fxChildTunnel-not-set");
    _checkToChainId(_toChainId);
  }

  /**
   * @notice Helper to increment nonce.
   * @return uint256 Incremented nonce
   */
  function _incrementNonce() internal returns (uint256) {
    unchecked {
      nonce++;
    }

    return nonce;
  }

  /**
   * @inheritdoc FxBaseRootTunnel
   * @dev This contract must not be used to receive and execute messages from Polygon.
   *      We need to implement the following function to be able to inherit from FxBaseRootTunnel.
   */
  function _processMessageFromChild(bytes memory data) internal override {
    /// no-op
  }
}
