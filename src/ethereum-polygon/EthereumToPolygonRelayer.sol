// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { FxBaseRootTunnel } from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";

import { ICrossChainExecutor } from "../interfaces/ICrossChainExecutor.sol";
import { ICrossChainRelayer } from "../interfaces/ICrossChainRelayer.sol";
import "../libraries/CallLib.sol";

/**
 * @title CrossChainRelayer contract
 * @notice The CrossChainRelayer contract allows a user or contract to send messages to another chain.
 *         It lives on the origin chain and communicates with the `CrossChainExecutor` contract on the receiving chain.
 */
contract CrossChainRelayerPolygon is ICrossChainRelayer, FxBaseRootTunnel {
  /* ============ Custom Errors ============ */

  /**
   * @notice Custom error emitted if the `gasLimit` passed to `relayCalls`
   *         is greater than the one provided for free on Polygon.
   * @param gasLimit Gas limit passed to `relayCalls`
   * @param maxGasLimit Gas limit provided for free on Polygon
   */
  error GasLimitTooHigh(uint256 gasLimit, uint256 maxGasLimit);

  /* ============ Variables ============ */

  /// @notice Gas limit provided for free on Polygon.
  uint256 public immutable maxGasLimit;

  /// @notice Nonce to uniquely idenfity each batch of calls.
  uint256 internal nonce;

  /// @notice Latest data relayed through the `CrossChainRelayer` contract.
  bytes public latestData;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainRelayer constructor.
   * @param _checkpointManager Address of the root chain manager contract on mainnet
   * @param _fxRoot Address of the state sender contract on mainnet
   * @param _maxGasLimit Gas limit provided for free on Polygon
   */
  constructor(
    address _checkpointManager,
    address _fxRoot,
    uint256 _maxGasLimit
  ) FxBaseRootTunnel(_checkpointManager, _fxRoot) {
    require(_maxGasLimit > 0, "Relayer/max-gas-limit-gt-zero");
    maxGasLimit = _maxGasLimit;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainRelayer
  function relayCalls(CallLib.Call[] calldata _calls, uint256 _gasLimit)
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

    _sendMessageToChild(abi.encode(_nonce, msg.sender, _calls));

    emit RelayedCalls(_nonce, msg.sender, _calls, _gasLimit);

    return _nonce;
  }

  /* ============ Internal Functions ============ */

  /// @inheritdoc FxBaseRootTunnel
  function _processMessageFromChild(bytes memory data) internal override {
    latestData = data;
  }
}
