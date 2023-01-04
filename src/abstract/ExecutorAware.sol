// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

/**
 * @title ExecutorAware abstract contract
 * @notice The ExecutorAware contract allows contracts on a receiving chain to execute calls from an origin chain.
 *         These calls are sent by the `MessageDispatcher` contract which live on the origin chain.
 *         The `MessageExecutor` contract on the receiving chain executes these calls
 *         and then forward them to an ExecutorAware contract on the receiving chain.
 * @dev This contract implements EIP-2771 (https://eips.ethereum.org/EIPS/eip-2771)
 *      to ensure that calls are sent by a trusted `MessageExecutor` contract.
 */
abstract contract ExecutorAware {
  /* ============ Variables ============ */

  /// @notice Address of the trusted executor contract.
  address public immutable trustedExecutor;

  /* ============ Constructor ============ */

  /**
   * @notice ExecutorAware constructor.
   * @param _executor Address of the `MessageExecutor` contract
   */
  constructor(address _executor) {
    require(_executor != address(0), "executor-not-zero-address");
    trustedExecutor = _executor;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Check which executor this contract trust.
   * @param _executor Address to check
   */
  function isTrustedExecutor(address _executor) public view returns (bool) {
    return _executor == trustedExecutor;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Retrieve nonce from call data.
   * @return _callDataNonce Nonce uniquely identifying the message that was executed
   */
  function _nonce() internal pure returns (uint256 _callDataNonce) {
    _callDataNonce;

    if (msg.data.length >= 84) {
      assembly {
        _callDataNonce := calldataload(sub(calldatasize(), 84))
      }
    }
  }

  /**
   * @notice Retrieve signer address from call data.
   * @return _signer Address of the signer
   */
  function _msgSender() internal view returns (address payable _signer) {
    _signer = payable(msg.sender);

    if (msg.data.length >= 52 && isTrustedExecutor(_signer)) {
      assembly {
        _signer := shr(96, calldataload(sub(calldatasize(), 52)))
      }
    }
  }

  /**
   * @notice Retrieve fromChainId from call data.
   * @return _callDataFromChainId ID of the chain that relayed the calls
   */
  function _fromChainId() internal pure returns (uint256 _callDataFromChainId) {
    _callDataFromChainId;

    if (msg.data.length >= 32) {
      assembly {
        _callDataFromChainId := calldataload(sub(calldatasize(), 32))
      }
    }
  }
}
