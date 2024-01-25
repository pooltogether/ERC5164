// SPDX-License-Identifier: MIT OR Apache-2.0

import "../../libraries/MessageLib.sol";
pragma solidity 0.8.16;

/**
 * @title EncodeDecodeUtil
 * @notice Library to encode and decode payloads.
 */
library EncodeDecodeUtil {
  /**
   * @notice Helper to encode a batch of messages that will be dispatched
   * @param messages Array of Message that will be dispatched
   * @param messageId ID uniquely identifying the batch of messages being dispatched
   * @param fromChainId ID of the chain that dispatched the batch of messages
   * @param from Address that dispatched the batch of messages
   */
  function encode(
    MessageLib.Message[] memory messages,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) internal pure returns (bytes memory) {
    return abi.encode(messages, messageId, fromChainId, from);
  }

  /**
   * @notice Helper to decode a batch of messages for that will be executed
   * @param _payload payload that is meant to be decoded
   
   */
  function decode(bytes memory _payload)
    internal
    pure
    returns (
      MessageLib.Message[] memory,
      bytes32,
      uint256,
      address
    )
  {
    (
      MessageLib.Message[] memory _messages,
      bytes32 messageId,
      uint256 fromChainId,
      address from
    ) = abi.decode(_payload, (MessageLib.Message[], bytes32, uint256, address));
    return (_messages, messageId, fromChainId, from);
  }
}
