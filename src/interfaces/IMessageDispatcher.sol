// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "../libraries/CallLib.sol";

/**
 * @title MessageDispatcher interface
 * @notice MessageDispatcher interface of the ERC-5164 standard as defined in the EIP.
 * @dev Use `IMessageDispatcherPayable` if the bridge you want to integrate requires a payment in the native currency.
 */
interface IMessageDispatcher {
  /**
   * @notice Emitted when calls have successfully been relayed to the executor chain.
   * @param nonce Nonce to uniquely identify the batch of calls
   * @param from Address of the sender
   * @param calls Array of calls being relayed
   * @param toChainId ID of the chain receiving the relayed `calls`
   */
  event RelayedCalls(
    uint256 indexed nonce,
    address indexed from,
    CallLib.Call[] calls,
    uint256 toChainId
  );

  /**
   * @notice Relay the call to the receiving chain.
   * @dev Must increment a `nonce` so that the `call` can be uniquely identified.
   * @dev Must emit the `RelayedCalls` event when successfully called.
   * @param call Call being relayed
   * @return uint256 Nonce to uniquely identify the call
   */
  function dispatchMessage(CallLib.Call calldata call) external returns (uint256);

  /**
   * @notice Relay the calls to the receiving chain.
   * @dev Must increment a `nonce` so that the batch of `calls` can be uniquely identified.
   * @dev Must emit the `RelayedCalls` event when successfully called.
   * @param calls Array of calls being relayed
   * @return uint256 Nonce to uniquely identify the batch of calls
   */
  function dispatchMessages(CallLib.Call[] calldata calls) external returns (uint256);
}
