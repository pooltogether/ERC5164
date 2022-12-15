// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

/**
 * @title CallLib
 * @notice Library to declare and manipulate Call(s).
 */
library CallLib {
  /* ============ Structs ============ */

  /**
   * @notice Call data structure
   * @param target Address that will be called on the receiving chain
   * @param data Data that will be sent to the `target` address
   */
  struct Call {
    address target;
    bytes data;
  }

  /* ============ Events ============ */

  /**
   * @notice Emitted if a call to a target contract fails.
   * @param callIndex Index of the call
   * @param errorData Error data returned by the call
   */
  event CallFailure(uint256 callIndex, bytes errorData);

  /**
   * @notice Emitted if a call to a target contract succeeds.
   * @param callIndex Index of the call
   * @param successData Error data returned by the call
   */
  event CallSuccess(uint256 callIndex, bytes successData);

  /* ============ Custom Errors ============ */

  /**
   * @notice Emitted when a batch of calls has already been executed.
   * @param nonce Nonce to uniquely identify the batch of calls that were re-executed
   */
  error CallsAlreadyExecuted(uint256 nonce);

  /* ============ Internal Functions ============ */

  /**
   * @notice Execute calls from the origin chain.
   * @dev Will revert if `_calls` have already been executed.
   * @param _nonce Nonce to uniquely idenfity the batch of calls
   * @param _sender Address of the sender on the origin chain
   * @param _calls Array of calls being executed
   * @param _executedNonce Whether `_calls` have already been executed or not
   * @return bool Whether the batch of calls was executed successfully or not
   */
  function executeCalls(
    uint256 _nonce,
    address _sender,
    Call[] memory _calls,
    bool _executedNonce
  ) internal returns (bool) {
    if (_executedNonce) {
      revert CallsAlreadyExecuted(_nonce);
    }

    uint256 _callsLength = _calls.length;

    for (uint256 _callIndex; _callIndex < _callsLength; ) {
      Call memory _call = _calls[_callIndex];

      require(_call.target != address(0), "CallLib/target-not-zero-address");

      (bool _success, bytes memory _returnData) = _call.target.call(
        abi.encodePacked(_call.data, _nonce, _sender)
      );

      if (!_success) {
        emit CallFailure(_callIndex, _returnData);
        return false;
      }

      emit CallSuccess(_callIndex, _returnData);

      unchecked {
        _callIndex++;
      }
    }

    return true;
  }
}
