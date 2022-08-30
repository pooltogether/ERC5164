// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger as IOptimismBridge } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import "../interfaces/ICrossChainRelayer.sol";

/**
 * @title CrossChainRelayer contract
 * @notice The CrossChainRelayer contract allows a user or contract to send messages to another chain.
 *         It lives on the origin chain and communicates with the `CrossChainReceiver` contract on the receiving chain.
 */
contract CrossChainRelayerOptimism is ICrossChainRelayer {
  /* ============ Variables ============ */

  /// @notice Address of the Optimism bridge on the origin chain.
  IOptimismBridge public immutable bridge;

  /// @notice Internal nonce enforcing replay protection.
  uint256 public nonce;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainRelayer constructor.
   * @param _bridge Address of the Optimism bridge
   */
  constructor(address _bridge) {
    require(_bridge != address(0), "Relayer/bridge-not-zero-address");
    bridge = IOptimismBridge(_bridge);
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainRelayer
  function relayCalls(
    ICrossChainReceiver _receiver,
    Call[] calldata _calls,
    uint256 _gasLimit
  ) external payable {
    nonce++;

    uint256 _nonce = nonce;
    IOptimismBridge _bridge = bridge;

    _bridge.sendMessage(
      address(_receiver),
      abi.encodeWithSignature(
        "receiveCalls(address,uint256,address,{address,bytes,uint256}[])",
        address(this),
        _nonce,
        address(_bridge),
        _calls
      ),
      uint32(_gasLimit)
    );

    emit RelayedCalls(_nonce, msg.sender, _receiver, _calls, _gasLimit);
  }
}
