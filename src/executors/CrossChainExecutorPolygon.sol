// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { FxBaseChildTunnel } from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseChildTunnel.sol";

/**
 * @title CrossChainExecutor contract
 * @notice The CrossChainExecutor contract executes call from the origin chain.
 *         These calls are sent by the `CrossChainRelayer` contract which live on the origin chain.
 */
contract CrossChainExecutorPolygon is FxBaseChildTunnel {
  /* ============ Structs ============ */

  /**
   * @notice Call data structure
   * @param target Address that will be called
   * @param data Data that will be sent to the `target` address
   */
  struct Call {
    address target;
    bytes data;
  }

  /* ============ Custom Errors ============ */

  /**
   * @notice Custom error emitted if a call to a target contract fails.
   * @param call Call struct
   * @param errorData Error data returned by the failed call
   */
  error CallFailure(Call call, bytes errorData);

  /* ============ Events ============ */

  /**
   * @notice Emitted when calls have successfully been executed.
   * @param relayer Address of the contract that relayed the calls
   * @param nonce Unique identifier
   * @param caller Address of the caller on the origin chain
   * @param calls Array of calls being executed
   */
  event ExecutedCalls(
    address indexed relayer,
    uint256 indexed nonce,
    address indexed caller,
    Call[] calls
  );

  /* ============ Variables ============ */

  /**
   * @notice Nonce to uniquely identify messages that were executed
   *         nonce => boolean
   * @dev Ensure that messages cannot be replayed once they have been executed
   */
  mapping(uint256 => bool) public executed;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainExecutor constructor.
   * @param _fxChild Address of the fx child contract on Polygon
   */
  constructor(address _fxChild) FxBaseChildTunnel(_fxChild) {}

  /* ============ Internal Functions ============ */

  /// @inheritdoc FxBaseChildTunnel
  function _processMessageFromRoot(
    uint256, /* _stateId */
    address _sender,
    bytes memory _data
  ) internal override validateSender(_sender) {
    (uint256 _nonce, address _caller, Call[] memory _calls) = abi.decode(
      _data,
      (uint256, address, Call[])
    );

    require(!executed[_nonce], "Executor/nonce-already-executed");

    uint256 _callsLength = _calls.length;

    for (uint256 _callIndex; _callIndex < _callsLength; _callIndex++) {
      Call memory _call = _calls[_callIndex];

      (bool _success, bytes memory _returnData) = _call.target.call(
        abi.encodePacked(_call.data, _nonce, _caller)
      );

      if (!_success) {
        revert CallFailure(_call, _returnData);
      }
    }

    executed[_nonce] = true;

    emit ExecutedCalls(_sender, _nonce, msg.sender, _calls);
  }
}
