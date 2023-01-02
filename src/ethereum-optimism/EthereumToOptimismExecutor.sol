// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../interfaces/ICrossChainExecutor.sol";
import "../libraries/CallLib.sol";

/**
 * @title CrossChainExecutorOptimism contract
 * @notice The CrossChainExecutorOptimism contract executes calls from the Ethereum chain.
 *         These calls are sent by the `CrossChainRelayerOptimism` contract which lives on the Ethereum chain.
 */
contract CrossChainExecutorOptimism is ICrossChainExecutor {
  /* ============ Custom Errors ============ */

  /**
   * @notice Emitted when a batch of calls fails to execute.
   * @param relayer Address of the contract that relayed the calls on the origin chain
   * @param nonce Nonce to uniquely identify the batch of calls that failed to execute
   */
  error ExecuteCallsFailed(ICrossChainRelayer relayer, uint256 nonce);

  /* ============ Variables ============ */

  /// @notice Address of the Optimism cross domain messenger on the Optimism chain.
  ICrossDomainMessenger public immutable crossDomainMessenger;

  /// @notice Address of the relayer contract on the Ethereum chain.
  ICrossChainRelayer public relayer;

  /**
   * @notice Nonce to uniquely identify the batch of calls that were executed
   *         nonce => boolean
   * @dev Ensure that batch of calls cannot be replayed once they have been executed.
   */
  mapping(uint256 => bool) public executed;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainExecutorOptimism constructor.
   * @param _crossDomainMessenger Address of the Optimism cross domain messenger on the Optimism chain
   */
  constructor(ICrossDomainMessenger _crossDomainMessenger) {
    require(address(_crossDomainMessenger) != address(0), "Executor/CDM-not-zero-address");
    crossDomainMessenger = _crossDomainMessenger;
  }

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
   * @notice Check if sender is authorized to call `executeCalls`.
   * @param _relayer Address of the relayer on the Ethereum chain
   */
  function _isAuthorized(ICrossChainRelayer _relayer) internal view {
    ICrossDomainMessenger _crossDomainMessenger = crossDomainMessenger;

    require(
      msg.sender == address(_crossDomainMessenger) &&
        _crossDomainMessenger.xDomainMessageSender() == address(_relayer),
      "Executor/sender-unauthorized"
    );
  }
}
