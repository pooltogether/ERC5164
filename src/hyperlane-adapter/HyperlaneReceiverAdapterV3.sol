// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.16;
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IMailbox } from "./interfaces/IMailbox.sol";
import { IMessageRecipient } from "./interfaces/IMessageRecipient.sol";
import { IInterchainSecurityModule, ISpecifiesInterchainSecurityModule } from "./interfaces/IInterchainSecurityModule.sol";
import { TypeCasts } from "./libraries/TypeCasts.sol";
import { EncodeDecodeUtil } from "./libraries/EncodeDecodeUtil.sol";
import { Errors } from "./libraries/Errors.sol";
import { IMessageDispatcher } from "../interfaces/IMessageDispatcher.sol";
import { IMessageExecutor } from "../interfaces/IMessageExecutor.sol";
import "../libraries/MessageLib.sol";

/**
 * @title HyperlaneReceiverAdapter implementation.
 * @notice `IBridgeReceiverAdapter` implementation that uses Hyperlane as the bridge.
 */
contract HyperlaneReceiverAdapterV3 is
  IMessageExecutor,
  IMessageRecipient,
  ISpecifiesInterchainSecurityModule,
  Ownable
{
  /// @notice `Mailbox` contract reference.
  IMailbox public immutable mailbox;

  /// @notice last message sender address
  bytes32 public lastSender;

  /// @notice last message received
  bytes public lastMessage;

  /// @notice `ISM` contract reference.
  IInterchainSecurityModule public ism;

  /**
   * @notice Sender adapter address for each source chain.
   * @dev srcChainId => senderAdapter address.
   */
  mapping(uint256 => IMessageDispatcher) public senderAdapters;

  /**
   * @notice Ensure that messages cannot be replayed once they have been executed.
   * @dev msgId => isExecuted.
   */
  mapping(bytes32 => bool) public executedMessages;

  /**
   * @notice Emitted when the ISM is set.
   * @param module The new ISM for this adapter/recipient.
   */
  event IsmSet(address indexed module);

  // /**
  //  * @notice Emitted when a message has successfully been executed.
  //  * @param fromChainId ID of the chain that dispatched the message
  //  * @param messageId ID uniquely identifying the message that was executed
  //  */
  // event MessageIdExecuted(
  //     uint256 indexed fromChainId,
  //     bytes32 indexed messageId
  // );

  /**
   * @notice Emitted when a messageId has already been executed.
   * @param messageId ID uniquely identifying the message or message batch that were re-executed
   */
  error MessageIdAlreadyExecuted(bytes32 messageId);

  /**
   * @notice Emitted when a sender adapter for a source chain is updated.
   * @param srcChainId Source chain identifier.
   * @param senderAdapter Address of the sender adapter.
   */
  event SenderAdapterUpdated(uint256 srcChainId, IMessageDispatcher senderAdapter);

  /* Constructor */
  /**
   * @notice HyperlaneReceiverAdapter constructor.
   * @param _mailbox Address of the Hyperlane `Mailbox` contract.
   */
  constructor(address _mailbox, address initialOwner) Ownable(initialOwner) {
    if (_mailbox == address(0)) {
      revert Errors.InvalidMailboxZeroAddress();
    }
    mailbox = IMailbox(_mailbox);
  }

  /// @notice Restrict access to trusted `Mailbox` contract.
  modifier onlyMailbox() {
    if (msg.sender != address(mailbox)) {
      revert Errors.UnauthorizedMailbox(msg.sender);
    }
    _;
  }

  /// @inheritdoc ISpecifiesInterchainSecurityModule
  function interchainSecurityModule() external view returns (IInterchainSecurityModule) {
    return ism;
  }

  /**
   * @notice Sets the ISM for this adapter/recipient.
   * @param _ism The ISM contract address.
   */
  function setIsm(address _ism) external onlyOwner {
    ism = IInterchainSecurityModule(_ism);
    emit IsmSet(_ism);
  }

  /**
   * @notice Called by Hyperlane `Mailbox` contract on destination chain to receive cross-chain messages.
   * @dev _origin Source chain domain identifier (not currently used).
   * @param _sender Address of the sender on the source chain.
   * @param _body Body of the message.
   */
  function handle(
    uint32 _origin,
    bytes32 _sender,
    bytes memory _body
  ) external payable onlyMailbox {
    address adapter = TypeCasts.bytes32ToAddress(_sender);
    //bool _executedMessageId;
    (
      MessageLib.Message[] memory _messages,
      bytes32 msgId,
      uint256 srcChainId,
      address srcSender
    ) = EncodeDecodeUtil.decode(_body);

    if (_origin != srcChainId) {
      revert Errors.UnauthorizedOrigin(_origin);
    }

    if (IMessageDispatcher(adapter) != senderAdapters[srcChainId]) {
      revert Errors.UnauthorizedAdapter(srcChainId, adapter);
    }

    if (_messages.length < 1) {
      revert Errors.NoMessagesSent(srcChainId);
    }

    if (executedMessages[msgId]) {
      revert MessageIdAlreadyExecuted(msgId);
    }
    //  else {
    //     executedMessages[msgId] = true;
    //     _executedMessageId = executedMessages[msgId];
    // }

    if (_messages.length == 1) {
      MessageLib.Message memory _message = _messages[0];
      executeMessage(_message.to, _message.data, msgId, srcChainId, srcSender);
    } else {
      executeMessageBatch(
        _messages,
        msgId,
        srcChainId,
        srcSender
        // _executedMessageId
      );
    }

    lastSender = _sender;
    lastMessage = _body;
  }

  function executeMessage(
    address _to,
    bytes memory _message,
    bytes32 _messageId,
    uint256 _fromChainId,
    address _from
  ) public override onlyMailbox {
    bool _executedMessageId = executedMessages[_messageId];
    executedMessages[_messageId] = true;

    MessageLib.executeMessage(_to, _message, _messageId, _fromChainId, _from, _executedMessageId);

    emit MessageIdExecuted(_fromChainId, _messageId);
  }

  function updateSenderAdapter(
    uint256[] calldata _srcChainIds,
    IMessageDispatcher[] calldata _senderAdapters
  ) external onlyOwner {
    if (_srcChainIds.length != _senderAdapters.length) {
      revert Errors.MismatchChainsAdaptersLength(_srcChainIds.length, _senderAdapters.length);
    }
    for (uint256 i; i < _srcChainIds.length; ++i) {
      senderAdapters[_srcChainIds[i]] = _senderAdapters[i];
      emit SenderAdapterUpdated(_srcChainIds[i], _senderAdapters[i]);
    }
  }

  function executeMessageBatch(
    MessageLib.Message[] memory _messages,
    bytes32 _messageId,
    uint256 _fromChainId,
    address _from // bool _executedMessageId
  ) public override onlyMailbox {
    executedMessages[_messageId] = true;
    bool _executedMessageId = executedMessages[_messageId];

    MessageLib.executeMessageBatch(_messages, _messageId, _fromChainId, _from, _executedMessageId);

    emit MessageIdExecuted(_fromChainId, _messageId);
  }

  function getSenderAdapter(
    uint256 _srcChainId
  ) public view returns (IMessageDispatcher _senderAdapter) {
    _senderAdapter = senderAdapters[_srcChainId];
  }
}
