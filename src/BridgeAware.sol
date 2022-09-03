// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

/**
 * @title BridgeAware contract
 * @notice The BridgeAware contract allows contracts on a receiving chain to receive calls from an origin chain.
 *         These calls are sent by the `CrossChainRelayer` contract which live on the origin chain.
 *         The `CrossChainReceiver` contract on the receiving chain receives these calls
 *         and then forward them to a BridgeAware contract on the receiving chain.
 * @dev This contract implements EIP 2771 (https://eips.ethereum.org/EIPS/eip-2771)
 *      to ensure that calls are sent by a trusted `CrossChainReceiver` contract.
 */
abstract contract BridgeAware {
  /* ============ Variables ============ */

  /**
   * @notice Address of the trusted forwarder contract as specified in EIP 2771.
   *         In our case, it is the `CrossChainReceiver` contract on the receiving chain.
   */
  address public immutable trustedForwarder;

  /* ============ Constructor ============ */

  /**
   * @notice BridgeAware constructor.
   * @param _receiver Address of the `CrossChainRelayer` contract
   */
  constructor(address _receiver) {
    require(_receiver != address(0), "receiver-not-zero-address");
    trustedForwarder = _receiver;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Check which forwarder this contract trust as specified in EIP 2771.
   * @param _forwarder Address to check
   */
  function isTrustedForwarder(address _forwarder) public view returns (bool) {
    return _forwarder == trustedForwarder;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Retrieve signer address as specified in EIP 2771.
   * @return _signer Address of the signer
   */
  function _msgSender() internal view returns (address payable _signer) {
    _signer = payable(msg.sender);

    if (msg.data.length >= 20 && isTrustedForwarder(_signer)) {
      assembly {
        _signer := shr(96, calldataload(sub(calldatasize(), 20)))
      }
    }
  }
}
