// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../interfaces/ICrossChainExecutor.sol";

/**
 * @title CrossChainExecutor contract
 * @notice The CrossChainExecutor contract executes call from the origin chain.
 *         These calls are sent by the `CrossChainRelayer` contract which live on the origin chain.
 */
contract CrossChainExecutorOptimism is ICrossChainExecutor {
  /* ============ Custom Errors ============ */

  /**
   * @notice Custom error emitted if a call to a target contract fails.
   * @param callIndex Index of the failed call
   * @param errorData Error data returned by the failed call
   */
  error CallFailure(uint256 callIndex, bytes errorData);

  /* ============ Variables ============ */

  /// @notice Address of the Optimism cross domain messenger on the receiving chain.
  ICrossDomainMessenger public immutable crossDomainMessenger;

  /// @notice Address of the relayer contract on the origin chain.
  ICrossChainRelayer public relayer;

  /**
   * @notice Nonce to uniquely identify messages that were executed
   *         nonce => boolean
   * @dev Ensure that messages cannot be replayed once they have been executed
   */
  mapping(uint256 => bool) public executed;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainExecutor constructor.
   * @param _crossDomainMessenger Address of the Optimism cross domain messenger
   */
  constructor(ICrossDomainMessenger _crossDomainMessenger) {
    require(address(_crossDomainMessenger) != address(0), "Executor/CDM-not-zero-address");
    crossDomainMessenger = _crossDomainMessenger;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainExecutor
  function executeCalls(
    uint256 _nonce,
    address _caller,
    Call[] calldata _calls
  ) external {
    require(!executed[_nonce], "Executor/nonce-already-executed");

    ICrossChainRelayer _relayer = relayer;

    _isAuthorized(_relayer);

    uint256 _callsLength = _calls.length;

    for (uint256 _callIndex; _callIndex < _callsLength; _callIndex++) {
      Call memory _call = _calls[_callIndex];

      (bool _success, bytes memory _returnData) = _call.target.call(
        abi.encodePacked(_call.data, _nonce, _caller)
      );

      if (!_success) {
        revert CallFailure(_callIndex, _returnData);
      }
    }

    executed[_nonce] = true;

    emit ExecutedCalls(_relayer, _nonce, msg.sender, _calls);
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
   * @notice Check if caller is authorized to call `executeCalls`.
   * @param _relayer Address of the relayer on the origin chain
   */
  function _isAuthorized(ICrossChainRelayer _relayer) internal view {
    ICrossDomainMessenger _crossDomainMessenger = crossDomainMessenger;

    require(
      msg.sender == address(_crossDomainMessenger) &&
        _crossDomainMessenger.xDomainMessageSender() == address(_relayer),
      "Executor/caller-unauthorized"
    );
  }
}
