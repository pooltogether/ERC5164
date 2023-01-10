// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { AddressAliasHelper } from "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";

import "../interfaces/IMessageExecutor.sol";
import "../libraries/CallLib.sol";

/**
 * @title MessageExecutorArbitrum contract
 * @notice The MessageExecutorArbitrum contract executes calls from the Ethereum chain.
 *         These calls are sent by the `MessageDispatcherArbitrum` contract which lives on the Ethereum chain.
 */
contract MessageExecutorArbitrum is IMessageExecutor {
  /* ============ Custom Errors ============ */

  /**
   * @notice Emitted when a batch of calls fails to execute.
   * @param fromChainId ID of the chain that relayed the batch of calls
   * @param dispatcher Address of the contract that relayed the calls on the origin chain
   * @param nonce Nonce to uniquely identify the batch of calls that failed to execute
   */
  error ExecuteCallsFailed(uint256 fromChainId, IMessageDispatcher dispatcher, uint256 nonce);

  /* ============ Variables ============ */

  /// @notice Address of the dispatcher contract on the Ethereum chain.
  IMessageDispatcher public dispatcher;

  /**
   * @notice Nonce to uniquely identify the batch of calls that were executed.
   *         nonce => boolean
   * @dev Ensure that batch of calls cannot be replayed once they have been executed.
   */
  mapping(uint256 => bool) public executed;

  /* ============ External Functions ============ */

  /// @inheritdoc IMessageExecutor
  function executeCalls(
    CallLib.Call[] calldata _calls,
    uint256 _nonce,
    address _from,
    uint256 _fromChainId
  ) external {
    IMessageDispatcher _dispatcher = dispatcher;
    _isAuthorized(_dispatcher);

    bool _executedNonce = executed[_nonce];
    executed[_nonce] = true;

    bool _callsExecuted = CallLib.executeCalls(_calls, _nonce, _from, _fromChainId, _executedNonce);

    if (!_callsExecuted) {
      revert ExecuteCallsFailed(_fromChainId, _dispatcher, _nonce);
    }

    emit ExecutedCalls(_fromChainId, _dispatcher, _nonce);
  }

  /**
   * @notice Set dispatcher contract address.
   * @dev Will revert if it has already been set.
   * @param _dispatcher Address of the dispatcher contract on the Ethereum chain
   */
  function setDispatcher(IMessageDispatcher _dispatcher) external {
    require(address(dispatcher) == address(0), "Executor/dispatcher-already-set");
    dispatcher = _dispatcher;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Check that the message came from the `dispatcher` on the Ethereum chain.
   * @dev We check that the sender is the L1 contract's L2 alias.
   * @param _dispatcher Address of the dispatcher on the Ethereum chain
   */
  function _isAuthorized(IMessageDispatcher _dispatcher) internal view {
    require(
      msg.sender == AddressAliasHelper.applyL1ToL2Alias(address(_dispatcher)),
      "Executor/sender-unauthorized"
    );
  }
}
