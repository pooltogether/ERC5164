// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { FxBaseChildTunnel } from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseChildTunnel.sol";

import "../libraries/CallLib.sol";

/**
 * @title MessageExecutorPolygon contract
 * @notice The MessageExecutorPolygon contract executes calls from the Ethereum chain.
 *         These calls are sent by the `MessageDispatcherPolygon` contract which lives on the Ethereum chain.
 */
contract MessageExecutorPolygon is FxBaseChildTunnel {
  /* ============ Custom Errors ============ */

  /**
   * @notice Emitted when a batch of calls fails to execute.
   * @param fromChainId ID of the chain that relayed the batch of calls
   * @param dispatcher Address of the contract that relayed the calls on the origin chain
   * @param nonce Nonce to uniquely identify the batch of calls that failed to execute
   */
  error ExecuteCallsFailed(uint256 fromChainId, address dispatcher, uint256 nonce);

  /* ============ Events ============ */

  /**
   * @notice Emitted when calls have successfully been executed.
   * @param fromChainId ID of the chain that relayed the batch of calls
   * @param dispatcher Address of the contract that relayed the calls
   * @param nonce Nonce to uniquely identify the batch of calls that were executed
   */
  event ExecutedCalls(
    uint256 indexed fromChainId,
    address indexed dispatcher,
    uint256 indexed nonce
  );

  /* ============ Variables ============ */

  /**
   * @notice Nonce to uniquely identify the batch of calls that were executed.
   *         nonce => boolean
   * @dev Ensure that batch of calls cannot be replayed once they have been executed.
   */
  mapping(uint256 => bool) public executed;

  /* ============ Constructor ============ */

  /**
   * @notice MessageExecutorPolygon constructor.
   * @param _fxChild Address of the FxChild contract on the Polygon chain
   */
  constructor(address _fxChild) FxBaseChildTunnel(_fxChild) {}

  /* ============ Internal Functions ============ */

  /// @inheritdoc FxBaseChildTunnel
  function _processMessageFromRoot(
    uint256, /* _stateId */
    address _sender,
    bytes memory _data
  ) internal override validateSender(_sender) {
    (CallLib.Call[] memory _calls, uint256 _nonce, address _from, uint256 _fromChainId) = abi
      .decode(_data, (CallLib.Call[], uint256, address, uint256));

    bool _executedNonce = executed[_nonce];
    executed[_nonce] = true;

    bool _callsExecuted = CallLib.executeCalls(_calls, _nonce, _from, _fromChainId, _executedNonce);

    if (!_callsExecuted) {
      revert ExecuteCallsFailed(_fromChainId, _sender, _nonce);
    }

    emit ExecutedCalls(_fromChainId, _sender, _nonce);
  }
}
