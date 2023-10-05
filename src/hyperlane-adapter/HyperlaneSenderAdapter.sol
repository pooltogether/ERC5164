// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.16;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IMailbox } from "./interfaces/IMailbox.sol";
import { IInterchainGasPaymaster } from "./interfaces/IInterchainGasPaymaster.sol";
import { TypeCasts } from "./libraries/TypeCasts.sol";
import { Errors } from "./libraries/Errors.sol";
import { IMessageDispatcher, ISingleMessageDispatcher } from "./interfaces/ISingleMessageDispatcher.sol";
import { IBatchedMessageDispatcher } from "./interfaces/IBatchedMessageDispatcher.sol";
import { IMessageExecutor } from "./interfaces/IMessageExecutor.sol";
import "../libraries/MessageLib.sol";

contract HyperlaneSenderAdapter is ISingleMessageDispatcher, IBatchedMessageDispatcher, Ownable {
  /// @notice `Mailbox` contract reference.
  IMailbox public immutable mailbox;

  /// @notice `IGP` contract reference.
  IInterchainGasPaymaster public igp;

  uint256 public nonce;

  /**
   * @notice Receiver adapter address for each destination chain.
   * @dev dstChainId => receiverAdapter address.
   */
  mapping(uint256 => IMessageExecutor) public receiverAdapters;

  mapping(uint256 => bool) public isValidChainId;

  /**
   * @notice Domain identifier for each destination chain.
   * @dev dstChainId => dstDomainId.
   */
  mapping(uint256 => uint32) public destinationDomains;

  /**
   * @notice Emitted when the IGP is set.
   * @param paymaster The new IGP for this adapter.
   */
  event IgpSet(address indexed paymaster);

  /**
   * @notice Emitted when a receiver adapter for a destination chain is updated.
   * @param dstChainId Destination chain identifier.
   * @param receiverAdapter Address of the receiver adapter.
   */
  event ReceiverAdapterUpdated(uint256 dstChainId, IMessageExecutor receiverAdapter);

  /**
   * @notice Emitted when a domain identifier for a destination chain is updated.
   * @param dstChainId Destination chain identifier.
   * @param dstDomainId Destination domain identifier.
   */
  event DestinationDomainUpdated(uint256 dstChainId, uint32 dstDomainId);

  /**
   * @notice HyperlaneSenderAdapter constructor.
   * @param _mailbox Address of the Hyperlane `Mailbox` contract.
   */
  constructor(address _mailbox, address _igp) {
    if (_mailbox == address(0)) {
      revert Errors.InvalidMailboxZeroAddress();
    }
    mailbox = IMailbox(_mailbox);
    _setIgp(_igp);
  }

  /// @dev we narrow mutability (from view to pure) to remove compiler warnings.
  /// @dev unused parameters are added as comments for legibility.
  function getMessageFee(
    uint256 toChainId,
    address,
    /* to*/
    bytes calldata /* data*/
  ) external view returns (uint256) {
    uint32 dstDomainId = _getDestinationDomain(toChainId);
    // destination gasAmount is hardcoded to 500k similar to Wormhole implementation
    // See https://docs.hyperlane.xyz/docs/build-with-hyperlane/guides/paying-for-interchain-gas
    try igp.quoteGasPayment(dstDomainId, 500000) returns (uint256 gasQuote) {
      return gasQuote;
    } catch {
      // Default to zero, MultiMessageSender.estimateTotalMessageFee doesn't expect this function to revert
      return 0;
    }
  }

  /**
   * @notice Sets the IGP for this adapter.
   * @dev See _setIgp.
   */
  function setIgp(address _igp) external onlyOwner {
    _setIgp(_igp);
  }

  function dispatchMessage(
    uint256 _toChainId,
    address _to,
    bytes calldata _data
  ) external payable returns (bytes32) {
    IMessageExecutor adapter = _getMessageExecutorAddress(_toChainId);
    _checkAdapter(_toChainId, adapter);
    uint32 dstDomainId = _getDestinationDomain(_toChainId);

    if (dstDomainId == 0) {
      revert Errors.UnknownDomainId(_toChainId);
    }

    uint256 _nonce = _incrementNonce();
    bytes32 msgId = MessageLib.computeMessageId(_nonce, msg.sender, _to, _data);

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({ to: _to, data: _data });

    bytes memory payload = abi.encode(_messages, msgId, block.chainid, msg.sender);

    bytes32 hyperlaneMsgId = IMailbox(mailbox).dispatch(
      dstDomainId,
      TypeCasts.addressToBytes32(address(adapter)), //receiver adapter is the reciever
      // Include the source chain id so that the receiver doesn't have to maintain a srcDomainId => srcChainId mapping
      payload
    );

    // try to make gas payment, ignore failures
    // destination gasAmount is hardcoded to 500k similar to Wormhole implementation
    // refundAddress is set from MMS caller state variable
    try
      igp.payForGas{ value: msg.value }(
        hyperlaneMsgId,
        dstDomainId,
        500000,
        //address(this)
        msg.sender
      )
    {} catch {}

    emit MessageDispatched(msgId, msg.sender, _toChainId, _to, _data);
    return msgId;
  }

  function dispatchMessageBatch(
    uint256 _toChainId,
    MessageLib.Message[] calldata _messages
  ) external payable returns (bytes32) {
    IMessageExecutor adapter = _getMessageExecutorAddress(_toChainId);
    _checkAdapter(_toChainId, adapter);
    uint32 dstDomainId = _getDestinationDomain(_toChainId);

    if (dstDomainId == 0) {
      revert Errors.UnknownDomainId(_toChainId);
    }

    uint256 _nonce = _incrementNonce();
    bytes32 msgId = MessageLib.computeMessageBatchId(_nonce, msg.sender, _messages);
    bytes memory payload = abi.encode(_messages, msgId, block.chainid, msg.sender);

    bytes32 hyperlaneMsgId = IMailbox(mailbox).dispatch(
      dstDomainId,
      TypeCasts.addressToBytes32(address(adapter)), //receiver adapter is the reciever
      // Include the source chain id so that the receiver doesn't have to maintain a srcDomainId => srcChainId mapping
      payload
    );

    // try to make gas payment, ignore failures
    // destination gasAmount is hardcoded to 500k similar to Wormhole implementation
    // refundAddress is set from MMS caller state variable
    try
      igp.payForGas{ value: msg.value }(
        hyperlaneMsgId,
        dstDomainId,
        500000,
        //address(this)
        msg.sender
      )
    {} catch {}

    emit MessageBatchDispatched(msgId, msg.sender, _toChainId, _messages);
    return msgId;
  }

  function updateReceiverAdapter(
    uint256[] calldata _dstChainIds,
    IMessageExecutor[] calldata _receiverAdapters
  ) external onlyOwner {
    if (_dstChainIds.length != _receiverAdapters.length) {
      revert Errors.MismatchChainsAdaptersLength(_dstChainIds.length, _receiverAdapters.length);
    }
    for (uint256 i; i < _dstChainIds.length; ++i) {
      receiverAdapters[_dstChainIds[i]] = _receiverAdapters[i];
      isValidChainId[_dstChainIds[i]] = true;
      emit ReceiverAdapterUpdated(_dstChainIds[i], _receiverAdapters[i]);
    }
  }

  function _checkAdapter(uint256 _destChainId, IMessageExecutor _executor) internal view {
    if (address(_executor) == address(0)) {
      revert Errors.InvalidAdapterZeroAddress();
    }

    IMessageExecutor executor = receiverAdapters[_destChainId];
    require(_executor == executor, "Dispatcher/executor-mis-match");
  }

  function getMessageExecutorAddress(
    uint256 _toChainId
  ) external view returns (address _executorAddress) {
    _executorAddress = address(_getMessageExecutorAddress(_toChainId));
  }

  /**
   * @notice Updates destination domain identifiers.
   * @param _dstChainIds Destination chain ids array.
   * @param _dstDomainIds Destination domain ids array.
   */
  function updateDestinationDomainIds(
    uint256[] calldata _dstChainIds,
    uint32[] calldata _dstDomainIds
  ) external onlyOwner {
    if (_dstChainIds.length != _dstDomainIds.length) {
      revert Errors.MismatchChainsDomainsLength(_dstChainIds.length, _dstDomainIds.length);
    }
    for (uint256 i; i < _dstChainIds.length; ++i) {
      destinationDomains[_dstChainIds[i]] = _dstDomainIds[i];
      emit DestinationDomainUpdated(_dstChainIds[i], _dstDomainIds[i]);
    }
  }

  /**
   * @notice Returns destination domain identifier for given destination chain id.
   * @dev dstDomainId is read from destinationDomains mapping
   * @dev Returned dstDomainId can be zero, reverting should be handled by consumers if necessary.
   * @param _dstChainId Destination chain id.
   * @return destination domain identifier.
   */
  function _getDestinationDomain(uint256 _dstChainId) internal view returns (uint32) {
    return destinationDomains[_dstChainId];
  }

  /**
   * @dev Sets the IGP for this adapter.
   * @param _igp The IGP contract address.
   */
  function _setIgp(address _igp) internal {
    igp = IInterchainGasPaymaster(_igp);
    emit IgpSet(_igp);
  }

  /**
   * @notice Check toChainId to ensure messages can be dispatched to this chain.
   * @dev Will revert if `_toChainId` is not supported.
   * @param _toChainId ID of the chain receiving the message
   */
  function _checkToChainId(uint256 _toChainId) internal view {
    bool status = isValidChainId[_toChainId];
    require(status, "Dispatcher/chainId-not-supported");
  }

  /**
   * @notice Retrieves address of the MessageExecutor contract on the receiving chain.
   * @dev Will revert if `_toChainId` is not supported.
   * @param _toChainId ID of the chain with which MessageDispatcher is communicating
   * @return receiverAdapter MessageExecutor contract address
   */
  function _getMessageExecutorAddress(
    uint256 _toChainId
  ) internal view returns (IMessageExecutor receiverAdapter) {
    _checkToChainId(_toChainId);
    receiverAdapter = receiverAdapters[_toChainId];
  }

  /// @dev Get current chain id
  function getChainId() public view virtual returns (uint256 cid) {
    assembly {
      cid := chainid()
    }
  }

  function getDestinationDomain(uint256 _dstChainId) public view returns (uint32 _destDomainId) {
    _destDomainId = _getDestinationDomain(_dstChainId);
  }

  /**
   * @notice Helper to increment nonce.
   * @return uint256 Incremented nonce
   */
  function _incrementNonce() internal returns (uint256) {
    unchecked {
      nonce++;
    }

    return nonce;
  }
}
