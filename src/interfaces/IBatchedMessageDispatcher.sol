// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "./IMessageDispatcher.sol";

/**
 * @title ERC-5164: Cross-Chain Execution Standard, optional BatchMessageDispatcher extension
 * @dev See https://eips.ethereum.org/EIPS/eip-5164
 */
interface IBatchedMessageDispatcher is IMessageDispatcher {
  /**
   * @notice Dispatch `messages` to the receiving chain.
   * @dev Must compute and return an ID uniquely identifying the `messages`.
   * @dev Must emit the `MessageBatchDispatched` event when successfully dispatched.
   * @param toChainId ID of the receiving chain
   * @param messages Array of Message dispatched
   * @return bytes32 ID uniquely identifying the `messages`
   */
  function dispatchMessageBatch(uint256 toChainId, MessageLib.Message[] calldata messages)
    external
    returns (bytes32);
}
