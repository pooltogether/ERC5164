// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "./ICrossChainRelayer.sol";

/**
 * @title CrossChainReceiver interface
 * @notice CrossChainReceiver interface of the ERC5164 standard as defined in the EIP.
 */
interface ICrossChainReceiver {
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
   * @notice Emitted when calls have successfully been received.
   * @param relayer Address of the contract that relayed the calls
   * @param nonce Unique identifier
   * @param caller Address of the caller on the origin chain
   * @param calls Array of calls being received
   */
  event ReceivedCalls(
    ICrossChainRelayer indexed relayer,
    uint256 indexed nonce,
    address indexed caller,
    Call[] calls
  );

  /**
   * @notice Receive calls from the origin chain.
   * @dev Should authenticate that the call has been performed by the bridge transport layer.
   * @dev Must emit the `ReceivedCalls` event when calls are received.
   * @param relayer Address who relayed the call on the origin chain
   * @param nonce Unique identifier
   * @param caller Address of the caller on the origin chain
   * @param calls Array of calls being received
   */
  function receiveCalls(
    ICrossChainRelayer relayer,
    uint256 nonce,
    address caller,
    Call[] calldata calls
  ) external;
}
