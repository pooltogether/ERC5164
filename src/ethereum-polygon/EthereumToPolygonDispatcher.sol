// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { FxBaseRootTunnel } from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";

import { IMessageDispatcher } from "../interfaces/IMessageDispatcher.sol";
import "../libraries/CallLib.sol";

/**
 * @title MessageDispatcherPolygon contract
 * @notice The MessageDispatcherPolygon contract allows a user or contract to send messages from Ethereum to Polygon.
 *         It lives on the Ethereum chain and communicates with the `MessageExecutorPolygon` contract on the Polygon chain.
 */
contract MessageDispatcherPolygon is IMessageDispatcher, FxBaseRootTunnel {
  /* ============ Variables ============ */

  /// @notice Nonce to uniquely identify each batch of calls.
  uint256 internal nonce;

  /// @notice ID of the chain receiving the relayed calls. i.e.: 137 for Mainnet, 80001 for Mumbai.
  uint256 internal toChainId;

  /* ============ Constructor ============ */

  /**
   * @notice MessageDispatcherPolygon constructor.
   * @param _checkpointManager Address of the root chain manager contract on Ethereum
   * @param _fxRoot Address of the state sender contract on Ethereum
   * @param _toChainId ID of the chain receiving the relayed calls
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

  /* ============ Internal Functions ============ */

  /**
   * @notice Relay calls to the receiving chain.
   * @param _calls Array of calls being relayed
   * @return uint256 Nonce to uniquely identify the batch of calls
   */
  function _dispatchMessages(CallLib.Call[] memory _calls) internal returns (uint256) {
    require(address(fxChildTunnel) != address(0), "Dispatcher/fxChildTunnel-not-set");

    unchecked {
      nonce++;
    }

    uint256 _nonce = nonce;

    _sendMessageToChild(abi.encode(_calls, _nonce, msg.sender, block.chainid));

    emit RelayedCalls(_nonce, msg.sender, _calls, toChainId);

    return _nonce;
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
