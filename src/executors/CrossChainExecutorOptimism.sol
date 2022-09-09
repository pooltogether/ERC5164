// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

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

  /// @notice Address of the Optimism bridge on the receiving chain.
  IOptimismBridge public immutable bridge;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainExecutor constructor.
   * @param _bridge Address of the Optimism bridge on the receiving chain
   */
  constructor(IOptimismBridge _bridge) {
    require(address(_bridge) != address(0), "Executor/bridge-not-zero-address");
    bridge = _bridge;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainExecutor
  function executeCalls(
    ICrossChainRelayer _relayer,
    uint256 _nonce,
    address _caller,
    Call[] calldata _calls
  ) external {
    address _bridge = address(bridge);

    _isAuthorized(_bridge, address(_relayer));

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

  /* ============ Internal Functions ============ */

  /**
   * @notice Check if caller is authorized to call `executeCalls`.
   * @param _bridge Address of the bridge on the receiving chain
   * @param _relayer Address of the relayer on the origin chain
   */
  function _isAuthorized(address _bridge, address _relayer) internal view {
    require(
      msg.sender == _bridge && IOptimismBridge(_bridge).xDomainMessageSender() == _relayer,
      "Executor/caller-unauthorized"
    );
  }
}
