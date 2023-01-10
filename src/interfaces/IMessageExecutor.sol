// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "./IMessageDispatcher.sol";

import "../libraries/CallLib.sol";

/**
 * @title MessageExecutor interface
 * @notice MessageExecutor interface of the ERC-5164 standard as defined in the EIP.
 */
interface IMessageExecutor {
  /**
   * @notice Emitted when calls have successfully been executed.
   * @param fromChainId ID of the chain that relayed the calls
   * @param dispatcher Address of the contract that relayed the calls on the origin chain
   * @param nonce Nonce to uniquely identify the batch of calls
   */
  event ExecutedCalls(
    uint256 indexed fromChainId,
    IMessageDispatcher indexed dispatcher,
    uint256 indexed nonce
  );

  /**
   * @notice Execute calls from the origin chain.
   * @dev Should authenticate that the call has been performed by the bridge transport layer.
   * @dev Must revert if a call fails.
   * @dev Must emit the `ExecutedCalls` event once calls have been executed.
   * @param calls Array of calls being executed
   * @param nonce Nonce to uniquely identify the batch of calls
   * @param from Address of the sender on the origin chain
   * @param fromChainId ID of the chain that relayed the calls
   */
  function executeCalls(
    CallLib.Call[] calldata calls,
    uint256 nonce,
    address from,
    uint256 fromChainId
  ) external;
}
