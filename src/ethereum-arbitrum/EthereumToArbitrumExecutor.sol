// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { AddressAliasHelper } from "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";

import "../interfaces/ICrossChainExecutor.sol";
import "../libraries/CallLib.sol";

/**
 * @title CrossChainExecutorArbitrum contract
 * @notice The CrossChainExecutorArbitrum contract executes calls from the Ethereum chain.
 *         These calls are sent by the `CrossChainRelayerArbitrum` contract which lives on the Ethereum chain.
 */
contract CrossChainExecutorArbitrum is ICrossChainExecutor {
  /* ============ Custom Errors ============ */

  /**
   * @notice Emitted when a batch of calls fails to execute.
   * @param relayer Address of the contract that relayed the calls on the origin chain
   * @param nonce Nonce to uniquely identify the batch of calls that failed to execute
   */
  error ExecuteCallsFailed(ICrossChainRelayer relayer, uint256 nonce);

  /* ============ Variables ============ */

  /// @notice Address of the relayer contract on the Ethereum chain.
  ICrossChainRelayer public relayer;

  /**
   * @notice Nonce to uniquely identify the batch of calls that were executed.
   *         nonce => boolean
   * @dev Ensure that batch of calls cannot be replayed once they have been executed.
   */
  mapping(uint256 => bool) public executed;

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainExecutor
  function executeCalls(
    uint256 _nonce,
    address _sender,
    CallLib.Call[] calldata _calls
  ) external {
    ICrossChainRelayer _relayer = relayer;
    _isAuthorized(_relayer);

    bool _executedNonce = executed[_nonce];
    executed[_nonce] = true;

    bool _callsExecuted = CallLib.executeCalls(_nonce, _sender, _calls, _executedNonce);

    if (!_callsExecuted) {
      revert ExecuteCallsFailed(_relayer, _nonce);
    }

    emit ExecutedCalls(_relayer, _nonce);
  }

  /**
   * @notice Set relayer contract address.
   * @dev Will revert if it has already been set.
   * @param _relayer Address of the relayer contract on the Ethereum chain
   */
  function setRelayer(ICrossChainRelayer _relayer) external {
    require(address(relayer) == address(0), "Executor/relayer-already-set");
    relayer = _relayer;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Check that the message came from the `relayer` on the Ethereum chain.
   * @dev We check that the sender is the L1 contract's L2 alias.
   * @param _relayer Address of the relayer on the Ethereum chain
   */
  function _isAuthorized(ICrossChainRelayer _relayer) internal view {
    require(
      msg.sender == AddressAliasHelper.applyL1ToL2Alias(address(_relayer)),
      "Executor/sender-unauthorized"
    );
  }
}
