// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { FxBaseRootTunnel } from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";

import { ICrossChainRelayer } from "../interfaces/ICrossChainRelayer.sol";
import "../libraries/CallLib.sol";

/**
 * @title CrossChainRelayerPolygon contract
 * @notice The CrossChainRelayerPolygon contract allows a user or contract to send messages from Ethereum to Polygon.
 *         It lives on the Ethereum chain and communicates with the `CrossChainExecutorPolygon` contract on the Polygon chain.
 */
contract CrossChainRelayerPolygon is ICrossChainRelayer, FxBaseRootTunnel {
  /* ============ Variables ============ */

  /// @notice Nonce to uniquely idenfity each batch of calls.
  uint256 internal nonce;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainRelayerPolygon constructor.
   * @param _checkpointManager Address of the root chain manager contract on Ethereum
   * @param _fxRoot Address of the state sender contract on Ethereum
   */
  constructor(address _checkpointManager, address _fxRoot)
    FxBaseRootTunnel(_checkpointManager, _fxRoot)
  {}

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainRelayer
  function relayCalls(CallLib.Call[] calldata _calls, uint256 _gasLimit)
    external
    returns (uint256)
  {
    require(address(fxChildTunnel) != address(0), "Relayer/fxChildTunnel-not-set");

    unchecked {
      nonce++;
    }

    uint256 _nonce = nonce;

    _sendMessageToChild(abi.encode(_nonce, msg.sender, _calls));

    emit RelayedCalls(_nonce, msg.sender, _calls, _gasLimit);

    return _nonce;
  }

  /* ============ Internal Functions ============ */

  /**
   * @inheritdoc FxBaseRootTunnel
   * @dev This contract must not be used to receive and execute messages from Polygon.
   *      We need to implement the following function to be able to inherit from FxBaseRootTunnel.
   */
  function _processMessageFromChild(bytes memory data) internal override {
    /// no-op
  }
}
