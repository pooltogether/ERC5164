// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import { ICrossChainExecutor } from "../interfaces/ICrossChainExecutor.sol";
import { ICrossChainRelayer } from "../interfaces/ICrossChainRelayer.sol";
import "../libraries/CallLib.sol";

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

  /// @notice Address of the Optimism cross domain messenger on the origin chain.
  ICrossDomainMessenger public immutable crossDomainMessenger;

  /// @notice Address of the executor contract on the receiving chain.
  ICrossChainExecutor public executor;

  /// @notice Gas limit provided for free on Optimism.
  uint256 public immutable maxGasLimit;

  /// @notice Nonce to uniquely idenfity each batch of calls.
  uint256 internal nonce;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainRelayer constructor.
   * @param _crossDomainMessenger Address of the Optimism cross domain messenger
   * @param _maxGasLimit Gas limit provided for free on Optimism
   */
  constructor(ICrossDomainMessenger _crossDomainMessenger, uint256 _maxGasLimit) {
    require(address(_crossDomainMessenger) != address(0), "Relayer/CDM-not-zero-address");
    require(_maxGasLimit > 0, "Relayer/max-gas-limit-gt-zero");

    crossDomainMessenger = _crossDomainMessenger;
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

    crossDomainMessenger.sendMessage(
      address(executor),
      abi.encodeWithSignature(
        "executeCalls(uint256,address,(address,bytes)[])",
        _nonce,
        msg.sender,
        _calls
      ),
      uint32(_gasLimit)
    );

    emit RelayedCalls(_nonce, msg.sender, _calls, _gasLimit);

    return _nonce;
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
}
