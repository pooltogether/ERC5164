// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import { IMessageDispatcher } from "../../src/interfaces/IMessageDispatcher.sol";
import { IMessageExecutor } from "../../src/interfaces/IMessageExecutor.sol";
import "../../src/hyperlane-adapter/HyperlaneSenderAdapterV3.sol";
import "../../src/hyperlane-adapter/HyperlaneReceiverAdapterV3.sol";
import "../../src/libraries/MessageLib.sol";
import { TypeCasts } from "../../src/hyperlane-adapter/libraries/TypeCasts.sol";
//import {MockHyperlaneEnvironment} from "../node_modules/@hyperlane-xyz/core/contracts/mock/MockHyperlaneEnvironment.sol";
//import {MockMailbox} from "../node_modules/@hyperlane-xyz/core/contracts/mock/MockMailbox.sol";
import { Greeter } from "../../test/contracts/Greeter.sol";
error Unauthorized();

//import {TestRecipient} from "./contracts/TestRecipient.sol";

contract TestHyperlaneAdapter is Test {
  //origin and destination domains (recommended to be the chainId)
  //   uint32 origin = 1;
  //   uint32 destination = 2;

  //   // both mailboxes will on the same chain but different addresses
  //   MockMailbox originMailbox;
  //   MockMailbox destinationMailbox;

  //   // contract which can receive messages
  //   TestRecipient receiver;

  uint256 public nonce = 1;
  uint256 public toChainId = 137;
  uint256 public fromChainId = 1;

  uint32 public dstDomainId = 137;
  uint32 public srcDomainId = 1;

  uint256 public mainnetFork;
  uint256 public polygonFork;

  address public owner;

  HyperlaneSenderAdapterV3 public dispatcher;
  HyperlaneReceiverAdapterV3 public executor;
  Greeter public greeter;
  IInterchainGasPaymaster public mainnetIgp;

  event ReceivedMessage(string message);

  address private constant MAINNET_MAILBOX = 0xc005dc82818d67AF737725bD4bf75435d065D239;
  address private constant POLYGON_MAILBOX = 0x5d934f4e2f797775e53561bB72aca21ba36B96BB;
  address private constant MAINNET_ISM = 0xec48E52D960E54a179f70907bF28b105813877ee;
  address private constant IGP = 0x9e6B1022bE9BBF5aFd152483DAD9b88911bC8611;

  string public mainnetGreeting = "Hello from mainnet";
  string public polygonGreeting = "Hello from polygon";

  IMailbox public constant mainnetMailbox = IMailbox(MAINNET_MAILBOX);
  IMailbox public constant polygonMailbox = IMailbox(POLYGON_MAILBOX);
  IInterchainSecurityModule public constant ism = IInterchainSecurityModule(MAINNET_ISM);

  event MessageDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    address to,
    bytes data
  );

  event MessageBatchDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    MessageLib.Message[] messages
  );

  event MessageIdExecuted(uint256 indexed fromChainId, bytes32 indexed messageId);

  event SetGreeting(
    string greeting,
    bytes32 messageId,
    uint256 fromChainId,
    address from,
    address recipient
  );

  /* ============ Errors to test ============ */

  error MessageFailure(uint256 messageIndex, bytes errorData);

  function setUp() public {
    // originMailbox = new MockMailbox(origin);
    // destinationMailbox = new MockMailbox(destination);
    // originMailbox.addRemoteMailbox(destination, destinationMailbox);

    // receiver = new TestRecipient();

    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    polygonFork = vm.createFork(vm.rpcUrl("polygon"));
    owner = 0x5e869af2Af006B538f9c6D231C31DE7cDB4153be;
    vm.label(owner, "Deployer");
    deployAll();
    setAll();
  }

  function deployDispatcher() public {
    vm.selectFork(mainnetFork);
    dispatcher = new HyperlaneSenderAdapterV3(MAINNET_MAILBOX, IGP, 0, owner);
    //mainnetIgp = IInterchainGasPaymaster(IGP);

    vm.makePersistent(address(dispatcher));
  }

  function deployExecutor() public {
    vm.selectFork(polygonFork);
    executor = new HyperlaneReceiverAdapterV3(POLYGON_MAILBOX, owner);

    vm.makePersistent(address(executor));
  }

  function deployGreeter() public {
    vm.selectFork(polygonFork);
    greeter = new Greeter(address(executor), polygonGreeting);

    vm.makePersistent(address(greeter));
  }

  function deployAll() public {
    deployDispatcher();
    deployExecutor();
    deployGreeter();
  }

  function updateDestinationDomains() public {
    vm.selectFork(mainnetFork);
    uint256[] memory _dstChainIds = new uint256[](1);
    uint32[] memory _dstDomainIds = new uint32[](1);
    _dstChainIds[0] = toChainId;
    _dstDomainIds[0] = 137;
    vm.prank(owner);
    dispatcher.updateDestinationDomainIds(_dstChainIds, _dstDomainIds);
  }

  function updateReceiverAdapter() public {
    vm.selectFork(mainnetFork);
    address executorAddr = address(executor);
    IMessageExecutor receiverAdapter = IMessageExecutor(executorAddr);
    uint256[] memory _dstChainIds = new uint256[](1);
    IMessageExecutor[] memory receiverAdapters = new IMessageExecutor[](1);
    _dstChainIds[0] = toChainId;
    receiverAdapters[0] = receiverAdapter;
    vm.prank(owner);
    dispatcher.updateReceiverAdapter(_dstChainIds, receiverAdapters);
  }

  function updateSenderAdapter() public {
    vm.selectFork(polygonFork);
    address dispatcherAddr = address(dispatcher);
    IMessageDispatcher senderAdapter = IMessageDispatcher(dispatcherAddr);
    uint256[] memory _srcChainIds = new uint256[](1);
    IMessageDispatcher[] memory senderAdapters = new IMessageDispatcher[](1);
    _srcChainIds[0] = fromChainId;
    senderAdapters[0] = senderAdapter;
    vm.prank(owner);
    executor.updateSenderAdapter(_srcChainIds, senderAdapters);
  }

  function setIsm() public {}

  function setAll() public {
    updateDestinationDomains();
    updateReceiverAdapter();
    updateSenderAdapter();
  }

  /* ============ Tests ============ */

  function testOwner() public {
    //deployAll();
    address expectedAddr = address(dispatcher.owner());
    assertEq(owner, expectedAddr);
  }

  function testUpdateDestinationDomainIds() public {
    //deployAll();

    //address expectedAddr = address(dispatcher.owner());
    //vm.prank(owner);
    uint32 expectedDomainID = dispatcher.getDestinationDomain(toChainId);
    assertEq(dstDomainId, expectedDomainID);
  }

  function testDispatchMessage() public {
    // deployAll();
    // setAll();

    vm.selectFork(mainnetFork);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (mainnetGreeting));

    bytes32 _expectedMessageId = MessageLib.computeMessageId(nonce, address(this), _to, _data);

    vm.expectEmit(true, true, true, true, address(dispatcher));
    emit MessageDispatched(_expectedMessageId, address(this), toChainId, _to, _data);

    uint256 fee = dispatcher.getMessageFee(toChainId, _to, _data);
    console.log(fee);

    bytes32 _messageId = dispatcher.dispatchMessage{ value: fee }(toChainId, _to, _data);
    assertEq(_messageId, _expectedMessageId);
  }

  /* ============ executeMessage ============ */
  function testHandle() public {
    vm.selectFork(polygonFork);

    assertEq(greeter.greet(), polygonGreeting);

    address _to = address(greeter);
    bytes memory _data = abi.encodeCall(Greeter.setGreeting, (mainnetGreeting));

    MessageLib.Message[] memory _messages = new MessageLib.Message[](1);
    _messages[0] = MessageLib.Message({ to: _to, data: _data });

    //vm.startPrank(address(polygonMailbox));

    bytes32 _expectedMessageId = MessageLib.computeMessageId(nonce, address(this), _to, _data);

    vm.expectEmit(true, true, true, true, address(greeter));
    emit SetGreeting(
      mainnetGreeting,
      _expectedMessageId,
      fromChainId,
      address(this),
      address(executor)
    );

    vm.expectEmit(true, true, true, true, address(executor));
    emit MessageIdExecuted(fromChainId, _expectedMessageId);

    bytes32 addressInBytes = TypeCasts.addressToBytes32(address(dispatcher));
    vm.prank(POLYGON_MAILBOX);
    bytes memory _body = abi.encode(_messages, _expectedMessageId, fromChainId, address(this));
    executor.handle(1, addressInBytes, _body);
    assertEq(executor.lastMessage(), _body);
    assertEq(greeter.greet(), mainnetGreeting);
  }

  //   function testSendMessage() public {
  //     string memory _message = "Aloha!";
  //     originMailbox.dispatch(
  //       destination,
  //       TypeCasts.addressToBytes32(address(receiver)),
  //       bytes(_message)
  //     );
  //     // simulating message delivery to the destinationMailbox
  //     destinationMailbox.processNextInboundMessage();
  //     assertEq(string(receiver.lastData()), _message);
  //   }
}
