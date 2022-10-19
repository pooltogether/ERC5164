// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "./ICrossChainExecutor.sol";

/**
 * @title CrossChainRelayer interface
 * @notice CrossChainRelayer interface of the ERC5164 standard as defined in the EIP.
 */
interface ICrossChainRelayer {
  /**
   * @notice Call data structure
   * @param target Address that will be called on the receiving chain
   * @param data Data that will be sent to the `target` address
   */
  struct Call {
    address target;
    bytes data;
  }

  /**
   * @notice Emitted when calls have successfully been relayed to the executor chain.
   * @param nonce Nonce to uniquely idenfity the batch of calls
   * @param sender Address of the sender
   * @param calls Array of calls being relayed
   * @param gasLimit Maximum amount of gas required for the `calls` to be executed
   */
  event RelayedCalls(uint256 indexed nonce, address indexed sender, Call[] calls, uint256 gasLimit);

  /**
   * @notice Relay the calls to the receiving chain.
   * @dev Must increment a `nonce` so that the batch of calls can be uniquely identified.
   * @dev Must emit the `RelayedCalls` event when successfully called.
   * @dev May require payment. Some bridges may require payment in the native currency, so the function is payable.
   * @param calls Array of calls being relayed
   * @param gasLimit Maximum amount of gas required for the `calls` to be executed
   * @return uint256 Nonce to uniquely idenfity the batch of calls
   */
  function relayCalls(Call[] calldata calls, uint256 gasLimit) external payable returns (uint256);
}
