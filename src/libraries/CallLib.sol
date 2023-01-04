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
   * @param to Address that will be called on the receiving chain
   * @param data Data that will be sent to the `to` address
   */
  struct Call {
    address to;
    bytes data;
  }

  /* ============ Events ============ */

  /**
   * @notice Emitted if a call to a contract fails.
   * @param nonce Nonce to uniquely identify the batch of calls
   * @param callIndex Index of the call
   * @param errorData Error data returned by the call
   */
  event CallFailure(uint256 nonce, uint256 callIndex, bytes errorData);

  /**
   * @notice Emitted if a call to a contract succeeds.
   * @param nonce Nonce to uniquely identify the batch of calls
   * @param callIndex Index of the call
   * @param successData Error data returned by the call
   */
  event CallSuccess(uint256 nonce, uint256 callIndex, bytes successData);

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
   * @param _calls Array of calls being executed
   * @param _nonce Nonce to uniquely identify the batch of calls
   * @param _from Address of the sender on the origin chain
   * @param _fromChainId ID of the chain that relayed the `_calls`
   * @param _executedNonce Whether `_calls` have already been executed or not
   * @return bool Whether the batch of calls was executed successfully or not
   */
  function executeCalls(
    Call[] memory _calls,
    uint256 _nonce,
    address _from,
    uint256 _fromChainId,
    bool _executedNonce
  ) internal returns (bool) {
    if (_executedNonce) {
      revert CallsAlreadyExecuted(_nonce);
    }

    uint256 _callsLength = _calls.length;

    for (uint256 _callIndex; _callIndex < _callsLength; ) {
      Call memory _call = _calls[_callIndex];

      require(_call.to.code.length > 0, "CallLib/no-contract-at-to");

      (bool _success, bytes memory _returnData) = _call.to.call(
        abi.encodePacked(_call.data, _nonce, _from, _fromChainId)
      );

      if (!_success) {
        emit CallFailure(_nonce, _callIndex, _returnData);
        return false;
      }

      emit CallSuccess(_nonce, _callIndex, _returnData);

      unchecked {
        _callIndex++;
      }
    }

    return true;
  }
}
