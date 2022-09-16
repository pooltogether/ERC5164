// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";

import "../interfaces/ICrossChainExecutor.sol";

/**
 * @title CrossChainExecutor contract
 * @notice The CrossChainExecutor contract executes call from the origin chain.
 *         These calls are sent by the `CrossChainRelayer` contract which live on the origin chain.
 */
contract CrossChainExecutorArbitrum is ICrossChainExecutor {
  /* ============ Custom Errors ============ */

  /**
   * @notice Custom error emitted if a call to a target contract fails.
   * @param call Call struct
   * @param errorData Error data returned by the failed call
   */
  error CallFailure(Call call, bytes errorData);

  /* ============ Variables ============ */

  /// @notice Address of the relayer contract on the origin chain.
  ICrossChainRelayer public relayer;

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainExecutor
  function executeCalls(
    uint256 _nonce,
    address _caller,
    Call[] calldata _calls
  ) external {
    ICrossChainRelayer _relayer = relayer;

    _isAuthorized(_relayer);

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
