// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "./ICrossChainReceiver.sol";

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
   * @notice Emitted when calls have successfully been relayed to the receiver chain.
   * @param nonce Unique identifier
   * @param sender Address of the sender
   * @param receiver Address of the CrossChainReceiver contract on the receiving chain
   * @param calls Array of calls being relayed
   * @param gasLimit Maximum amount of gas required for the `calls` to be executed
   */
  event RelayedCalls(
    uint256 indexed nonce,
    address indexed sender,
    ICrossChainReceiver indexed receiver,
    Call[] calls,
    uint256 gasLimit
  );

  /**
   * @notice Relay the calls to the receiving chain.
   * @dev Must implement `ICrossChainReceiver.receiveCalls` to relay the calls on the receiving chain.
   * @dev Must increment a `nonce` so that each batch of calls can be uniquely identified.
   * @dev Must emit the `RelayedCalls` event when successfully called.
   * @dev May require payment. Some bridges may require payment in the native currency, so the function is payable.
   * @param receiver Address who will receive the calls on the receiving chain
   * @param calls Array of calls being relayed
   * @param gasLimit Maximum amount of gas required for the `calls` to be executed
   */
  function relayCalls(
    ICrossChainReceiver receiver,
    Call[] calldata calls,
    uint256 gasLimit
  ) external payable;
}
