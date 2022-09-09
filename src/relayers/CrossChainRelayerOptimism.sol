// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../interfaces/ICrossChainRelayer.sol";

/**
 * @title CrossChainRelayer contract
 * @notice The CrossChainRelayer contract allows a user or contract to send messages to another chain.
 *         It lives on the origin chain and communicates with the `CrossChainExecutor` contract on the receiving chain.
 */
contract CrossChainRelayerOptimism is ICrossChainRelayer {
  /* ============ Custom Errors ============ */

  /**
   * @notice Custom error emitted if the `gasLimit` passed to `relayCalls`
   *         is greater than the one provided for free on Optimism.
   * @param gasLimit Gas limit passed to `relayCalls`
   * @param maxGasLimit Gas limit provided for free on Optimism
   */
  error GasLimitTooHigh(uint256 gasLimit, uint256 maxGasLimit);

  /* ============ Variables ============ */

  /// @notice Address of the Optimism bridge on the origin chain.
  IOptimismBridge public immutable bridge;

  /// @notice Gas limit provided for free on Optimism.
  uint256 public immutable maxGasLimit;

  /// @notice Internal nonce to uniquely idenfity each batch of calls.
  uint256 internal nonce;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainRelayer constructor.
   * @param _bridge Address of the Optimism bridge
   * @param _maxGasLimit Gas limit provided for free on Optimism
   */
  constructor(IOptimismBridge _bridge, uint256 _maxGasLimit) {
    require(address(_bridge) != address(0), "Relayer/bridge-not-zero-address");
    require(_maxGasLimit > 0, "Relayer/max-gas-limit-gt-zero");

    bridge = _bridge;
    maxGasLimit = _maxGasLimit;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainRelayer
  function relayCalls(
    ICrossChainExecutor _executor,
    Call[] calldata _calls,
    uint256 _gasLimit
  ) external payable {
    uint256 _maxGasLimit = maxGasLimit;

    if (_gasLimit > _maxGasLimit) {
      revert GasLimitTooHigh(_gasLimit, _maxGasLimit);
    }

    nonce++;

    uint256 _nonce = nonce;
    IOptimismBridge _bridge = bridge;

    _bridge.sendMessage(
      address(_executor),
      abi.encodeWithSignature(
        "executeCalls(address,uint256,address,(address,bytes)[])",
        address(this),
        _nonce,
        msg.sender,
        _calls
      ),
      uint32(_gasLimit)
    );

    emit RelayedCalls(_nonce, msg.sender, _executor, _calls, _gasLimit);
  }
}
