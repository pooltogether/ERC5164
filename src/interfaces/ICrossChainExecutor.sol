// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "./ICrossChainRelayer.sol";

import "../libraries/CallLib.sol";

/**
 * @title CrossChainExecutor interface
 * @notice CrossChainExecutor interface of the ERC-5164 standard as defined in the EIP.
 */
interface ICrossChainExecutor {
  /**
   * @notice Emitted when calls have successfully been executed.
   * @param relayer Address of the contract that relayed the calls on the origin chain
   * @param nonce Nonce to uniquely identify the batch of calls
   */
  event ExecutedCalls(ICrossChainRelayer indexed relayer, uint256 indexed nonce);

  /**
   * @notice Execute calls from the origin chain.
   * @dev Should authenticate that the call has been performed by the bridge transport layer.
   * @dev Must revert if a call fails.
   * @dev Must emit the `ExecutedCalls` event once calls have been executed.
   * @param nonce Nonce to uniquely idenfity the batch of calls
   * @param sender Address of the sender on the origin chain
   * @param calls Array of calls being executed
   */
  function executeCalls(
    uint256 nonce,
    address sender,
    CallLib.Call[] calldata calls
  ) external;
}
