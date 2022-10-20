// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { AddressAliasHelper } from "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";

import "../interfaces/ICrossChainExecutor.sol";
import "../libraries/CallLib.sol";

/**
 * @title CrossChainExecutor contract
 * @notice The CrossChainExecutor contract executes call from the origin chain.
 *         These calls are sent by the `CrossChainRelayer` contract which live on the origin chain.
 */
contract CrossChainExecutorArbitrum is ICrossChainExecutor {
  /* ============ Variables ============ */

  /// @notice Address of the relayer contract on the origin chain.
  ICrossChainRelayer public relayer;

  /**
   * @notice Nonce to uniquely identify the batch of calls that were executed
   *         nonce => boolean
   * @dev Ensure that batch of calls cannot be replayed once they have been executed
   */
  mapping(uint256 => bool) public executed;

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainExecutor
  function executeCalls(
    uint256 _nonce,
    address _caller,
    CallLib.Call[] calldata _calls
  ) external {
    ICrossChainRelayer _relayer = relayer;
    _isAuthorized(_relayer);

    CallLib.executeCalls(_nonce, _caller, _calls, executed[_nonce]);
    executed[_nonce] = true;

    emit ExecutedCalls(_relayer, _nonce);
  }

  /**
   * @notice Set relayer contract address.
   * @dev Will revert if it has already been set.
   * @param _relayer Address of the relayer contract
   */
  function setRelayer(ICrossChainRelayer _relayer) external {
    require(address(relayer) == address(0), "Executor/relayer-already-set");
    relayer = _relayer;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Check that the message came from the `relayer` on the origin chain.
   * @dev We check that the sender is the L1 contract's L2 alias.
   * @param _relayer Address of the relayer on the origin chain
   */
  function _isAuthorized(ICrossChainRelayer _relayer) internal view {
    require(
      msg.sender == AddressAliasHelper.applyL1ToL2Alias(address(_relayer)),
      "Executor/caller-unauthorized"
    );
  }
}
