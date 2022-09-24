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
   * @param call Call struct
   * @param errorData Error data returned by the failed call
   */
  error CallFailure(Call call, bytes errorData);

  /* ============ Variables ============ */

  /// @notice Address of the Optimism cross domain messenger on the receiving chain.
  ICrossDomainMessenger public immutable crossDomainMessenger;

  /// @notice Address of the relayer contract on the origin chain.
  ICrossChainRelayer public relayer;

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
    _isAuthorized();

    uint256 _callsLength = _calls.length;

    for (uint256 _callIndex; _callIndex < _callsLength; _callIndex++) {
      Call memory _call = _calls[_callIndex];

      (bool _success, bytes memory _returnData) = _call.target.call(
        abi.encodePacked(_call.data, _caller)
      );

      if (!_success) {
        revert CallFailure(_call, _returnData);
      }
    }

    emit ExecutedCalls(relayer, _nonce, msg.sender, _calls);
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

  /// @notice Check if caller is authorized to call `executeCalls`.
  function _isAuthorized() internal view {
    ICrossDomainMessenger _crossDomainMessenger = crossDomainMessenger;

    require(
      msg.sender == address(_crossDomainMessenger) &&
        _crossDomainMessenger.xDomainMessageSender() == address(relayer),
      "Executor/caller-unauthorized"
    );
  }
}
