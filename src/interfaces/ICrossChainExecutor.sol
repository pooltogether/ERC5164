// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "./ICrossChainRelayer.sol";

/**
 * @title CrossChainExecutor interface
 * @notice CrossChainExecutor interface of the ERC5164 standard as defined in the EIP.
 */
interface ICrossChainExecutor {
  /**
   * @notice Call data structure
   * @param target Address that will be called
   * @param data Data that will be sent to the `target` address
   */
  struct Call {
    address target;
    bytes data;
  }

  /**
   * @notice Emitted when calls have successfully been executed.
   * @param relayer Address of the contract that relayed the calls on the origin chain
   * @param nonce Nonce to uniquely identify each batch of calls
   * @param caller Address of the caller on the origin chain
   * @param calls Array of calls being executed
   */
  event ExecutedCalls(
    ICrossChainRelayer indexed relayer,
    uint256 indexed nonce,
    address indexed caller,
    Call[] calls
  );

  /**
   * @notice Execute calls from the origin chain.
   * @dev Should authenticate that the call has been performed by the bridge transport layer.
   * @dev Must emit the `ExecutedCalls` event once calls have been executed.
   * @param nonce Nonce to uniquely idenfity each batch of calls
   * @param caller Address of the caller on the origin chain
   * @param calls Array of calls being executed
   */
  function executeCalls(
    uint256 nonce,
    address caller,
    Call[] calldata calls
  ) external;
}
