// SPDX-License-Identifier: MIT OR Apache-2.0
// Extracted from https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/solidity/interfaces/IMailbox.sol
pragma solidity 0.8.16;

interface IMailbox {
  function quoteDispatch(
    uint32 destination,
    bytes32 recipient,
    bytes calldata _messageBody
  ) external view returns (uint256 fee);

  function dispatch(
    uint32 _destinationDomain,
    bytes32 _recipientAddress,
    bytes calldata _messageBody
  ) external payable; // will revert if msg.value < quoted fee
}

// /// @dev imported from
// /// https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/v3/solidity/contracts/interfaces/hooks/IPostDispatchHook.sol
// interface IPostDispatchHook {
//     enum Types {
//         UNUSED,
//         ROUTING,
//         AGGREGATION,
//         MERKLE_TREE,
//         INTERCHAIN_GAS_PAYMASTER,
//         FALLBACK_ROUTING,
//         ID_AUTH_ISM,
//         PAUSABLE,
//         PROTOCOL_FEE
//     }
// }
