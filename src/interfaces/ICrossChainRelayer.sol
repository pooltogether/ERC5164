// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "../libraries/CallLib.sol";

/**
 * @title CrossChainRelayer interface
 * @notice CrossChainRelayer interface of the ERC-5164 standard as defined in the EIP.
 */
interface ICrossChainRelayer {
  /**
   * @notice Custom error emitted if the `gasLimit` passed to `relayCalls`
   *         is greater than the one provided for free on the receiving chain.
   * @param gasLimit Gas limit passed to `relayCalls`
   * @param maxGasLimit Gas limit provided for free on the receiving chain
   */
  error GasLimitTooHigh(uint256 gasLimit, uint256 maxGasLimit);

  /**
   * @notice Emitted when calls have successfully been relayed to the executor chain.
   * @param nonce Nonce to uniquely idenfity the batch of calls
   * @param sender Address of the sender
   * @param calls Array of calls being relayed
   * @param gasLimit Maximum amount of gas required for the `calls` to be executed
   */
  event RelayedCalls(
    uint256 indexed nonce,
    address indexed sender,
    CallLib.Call[] calls,
    uint256 gasLimit
  );

  /**
   * @notice Relay the calls to the receiving chain.
   * @dev Must increment a `nonce` so that the batch of calls can be uniquely identified.
   * @dev Must emit the `RelayedCalls` event when successfully called.
   * @dev May require payment. Some bridges may require payment in the native currency, so the function is payable.
   * @param calls Array of calls being relayed
   * @param gasLimit Maximum amount of gas required for the `calls` to be executed
   * @return uint256 Nonce to uniquely idenfity the batch of calls
   */
  function relayCalls(CallLib.Call[] calldata calls, uint256 gasLimit)
    external
    payable
    returns (uint256);
}
