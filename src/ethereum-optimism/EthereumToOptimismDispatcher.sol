// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

import { IMessageExecutor } from "../interfaces/IMessageExecutor.sol";
import { IMessageDispatcher } from "../interfaces/IMessageDispatcher.sol";
import "../libraries/CallLib.sol";

/**
 * @title MessageDispatcherOptimism contract
 * @notice The MessageDispatcherOptimism contract allows a user or contract to send messages from Ethereum to Optimism.
 *         It lives on the Ethereum chain and communicates with the `MessageExecutorOptimism` contract on the Optimism chain.
 */
contract MessageDispatcherOptimism is IMessageDispatcher {
  /* ============ Variables ============ */

  /// @notice Address of the Optimism cross domain messenger on the Ethereum chain.
  ICrossDomainMessenger public immutable crossDomainMessenger;

  /// @notice Address of the executor contract on the Optimism chain.
  IMessageExecutor public executor;

  /// @notice Nonce to uniquely identify each batch of calls.
  uint256 internal nonce;

  /// @notice ID of the chain receiving the relayed calls. i.e.: 10 for Mainnet, 420 for Goerli.
  uint256 internal toChainId;

  /* ============ Constructor ============ */

  /**
   * @notice MessageDispatcherOptimism constructor.
   * @param _crossDomainMessenger Address of the Optimism cross domain messenger
   * @param _toChainId ID of the chain receiving the relayed calls
   */
  constructor(ICrossDomainMessenger _crossDomainMessenger, uint256 _toChainId) {
    require(address(_crossDomainMessenger) != address(0), "Dispatcher/CDM-not-zero-address");
    require(_toChainId != 0, "Dispatcher/chainId-not-zero");

    crossDomainMessenger = _crossDomainMessenger;
    toChainId = _toChainId;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc IMessageDispatcher
  function dispatchMessage(CallLib.Call calldata _call) external returns (uint256) {
    CallLib.Call[] memory _calls = new CallLib.Call[](1);
    _calls[0] = _call;

    return _dispatchMessages(_calls);
  }

  /// @inheritdoc IMessageDispatcher
  function dispatchMessages(CallLib.Call[] calldata _calls) external returns (uint256) {
    return _dispatchMessages(_calls);
  }

  /**
   * @notice Set executor contract address.
   * @dev Will revert if it has already been set.
   * @param _executor Address of the executor contract on the Optimism chain
   */
  function setExecutor(IMessageExecutor _executor) external {
    require(address(executor) == address(0), "Dispatcher/executor-already-set");
    executor = _executor;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Relay calls to the receiving chain.
   * @param _calls Array of calls being relayed
   * @return uint256 Nonce to uniquely identify the batch of calls
   */
  function _dispatchMessages(CallLib.Call[] memory _calls) internal returns (uint256) {
    address _executorAddress = address(executor);
    require(_executorAddress != address(0), "Dispatcher/executor-not-set");

    unchecked {
      nonce++;
    }

    uint256 _nonce = nonce;

    crossDomainMessenger.sendMessage(
      _executorAddress,
      abi.encodeWithSelector(IMessageExecutor.executeCalls.selector, _nonce, msg.sender, _calls),
      uint32(1920000)
    );

    emit RelayedCalls(_nonce, msg.sender, _calls, toChainId);

    return _nonce;
  }
}
