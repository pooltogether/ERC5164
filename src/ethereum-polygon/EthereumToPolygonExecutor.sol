// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { FxBaseChildTunnel } from "@maticnetwork/fx-portal/contracts/tunnel/FxBaseChildTunnel.sol";

import "../libraries/CallLib.sol";

/**
 * @title CrossChainExecutorPolygon contract
 * @notice The CrossChainExecutorPolygon contract executes calls from the Ethereum chain.
 *         These calls are sent by the `CrossChainRelayerPolygon` contract which lives on the Ethereum chain.
 */
contract CrossChainExecutorPolygon is FxBaseChildTunnel {
  /* ============ Events ============ */

  /**
   * @notice Emitted when calls have successfully been executed.
   * @param relayer Address of the contract that relayed the calls
   * @param nonce Nonce to uniquely identify the batch of calls that were executed
   */
  event ExecutedCalls(address indexed relayer, uint256 indexed nonce);

  /* ============ Variables ============ */

  /**
   * @notice Nonce to uniquely identify the batch of calls that were executed.
   *         nonce => boolean
   * @dev Ensure that batch of calls cannot be replayed once they have been executed.
   */
  mapping(uint256 => bool) public executed;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainExecutorPolygon constructor.
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
    (uint256 _nonce, address _callsSender, CallLib.Call[] memory _calls) = abi.decode(
      _data,
      (uint256, address, CallLib.Call[])
    );

    bool _executedNonce = executed[_nonce];
    executed[_nonce] = true;

    CallLib.executeCalls(_nonce, _callsSender, _calls, _executedNonce);

    emit ExecutedCalls(_sender, _nonce);
  }
}
