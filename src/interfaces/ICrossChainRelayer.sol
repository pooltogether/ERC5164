// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "../libraries/CallLib.sol";

/**
 * @title CrossChainRelayer interface
 * @notice CrossChainRelayer interface of the ERC-5164 standard as defined in the EIP.
 * @dev Use `ICrossChainRelayerPayable` if the bridge you want to integrate requires a payment in the native currency.
 */
interface ICrossChainRelayer {
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
   * @param calls Array of calls being relayed
   * @param gasLimit Maximum amount of gas required for the `calls` to be executed
   * @return uint256 Nonce to uniquely idenfity the batch of calls
   */
  function relayCalls(CallLib.Call[] calldata calls, uint256 gasLimit) external returns (uint256);
}
