// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "../../src/axelar/AxelarTransceiver.sol";
import "../../src/axelar/AxelarTransceiverProxy.sol";
import "./mock/MockGateway.sol";
import {MockAxelarGasService} from "./mock/MockGasService.sol";
import {TransceiverStructs} from
    "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";
import {NttManager} from "@wormhole-foundation/native_token_transfer/NttManager/NttManager.sol";
import {INttManager} from "@wormhole-foundation/native_token_transfer/interfaces/INttManager.sol";
import {IManagerBase} from "@wormhole-foundation/native_token_transfer/interfaces/IManagerBase.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WstEthL2Token} from "src/token/WstEthL2Token.sol";
import {WstEthL2TokenHarness} from "test/token/WstEthL2TokenHarness.sol";
import {Upgrades} from "script/lib/Upgrades.sol";

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract AxelarTransceiverTest is Test {
    event ContractCall(
        address indexed sender,
        string destinationChain,
        string destinationContractAddress,
        bytes32 indexed payloadHash,
        bytes payload
    );

    event AxelarChainIdSet(uint16 chainId, string chainName, string transceiverAddress);

    address constant OWNER = address(1004);

    uint64 constant RATE_LIMIT_DURATION = 0;
    bool constant SKIP_RATE_LIMITING = true;

    uint256 constant DEVNET_GUARDIAN_PK =
        0xcfb12303a19cde580bb4dd771639b0d26bc68353645571a8cff516ab2ee113a0;

    AxelarTransceiver transceiver;
    IAxelarGateway gateway;
    IAxelarGasService gasService;
    NttManager manager;
    WstEthL2TokenHarness token;

    function setUp() public {
        gateway = IAxelarGateway(new MockAxelarGateway());
        gasService = IAxelarGasService(address(new MockAxelarGasService()));

        // Deploy the token
        address proxy = Upgrades.deployUUPSProxy(
            "out/ERC1967Proxy.sol/ERC1967Proxy.json",
            "WstEthL2TokenHarness.sol",
            abi.encodeCall(WstEthL2Token.initialize, ("Wrapped Staked Eth", "wstEth", OWNER))
        );
        vm.label(proxy, "Proxy");

        token = WstEthL2TokenHarness(proxy);

        address managerImplementation = address(
            new NttManager(
                address(token),
                IManagerBase.Mode.LOCKING,
                1,
                RATE_LIMIT_DURATION,
                SKIP_RATE_LIMITING
            )
        );
        manager = NttManager(address(new ERC1967Proxy(managerImplementation, "")));
        manager.initialize();
        manager.transferOwnership(OWNER);
        address implementation =
            address(new AxelarTransceiver(address(gateway), address(gasService), address(manager)));
        transceiver = AxelarTransceiver(address(new ERC1967Proxy(implementation, "")));
        transceiver.initialize();
        vm.prank(OWNER);
        manager.setTransceiver(address(transceiver));
    }

    function test_setAxelarChainId() public {
        uint16 chainId = 1;
        string memory chainName = "chainName";
        string memory axelarAddress = "axelarAddress";

        vm.expectEmit(address(transceiver));
        emit AxelarChainIdSet(chainId, chainName, axelarAddress);

        vm.prank(OWNER);
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);
    }

    function test_setAxelarChainIdDuplicateChainId() public {
        uint16 chainId = 1;
        string memory chainName = "chainName";
        string memory axelarAddress = "axelarAddress";

        vm.expectEmit(address(transceiver));
        emit AxelarChainIdSet(chainId, chainName, axelarAddress);

        vm.prank(OWNER);
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("ChainIdAlreadySet(uint16)", chainId));
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("AxelarChainIdAlreadySet(string)", chainName));
        transceiver.setAxelarChainId(chainId + 1, chainName, axelarAddress);
    }

    function test_setAxelarChainIdNotOwner() public {
        uint16 chainId = 1;
        string memory chainName = "chainName";
        string memory axelarAddress = "axelarAddress";
        address sender = address(0x012345);

        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", sender));
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);
    }

    function test_sendMessage() public {
        uint16 chainId = 1;
        string memory chainName = "chainName";
        string memory axelarAddress = "axelarAddress";
        bytes32 recipientNttManagerAddress = bytes32(uint256(1010));
        bytes memory nttManagerMessage = bytes("nttManagerMessage");
        bytes32 refundAddress = bytes32(uint256(1011));
        bytes memory payload = abi.encode(manager, nttManagerMessage, recipientNttManagerAddress);
        TransceiverStructs.TransceiverInstruction memory instruction =
            TransceiverStructs.TransceiverInstruction(0, bytes(""));

        vm.prank(OWNER);
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);

        vm.expectEmit(address(gateway));
        emit ContractCall(
            address(transceiver), chainName, axelarAddress, keccak256(payload), payload
        );

        vm.prank(address(manager));
        transceiver.sendMessage(
            chainId, instruction, nttManagerMessage, recipientNttManagerAddress, refundAddress
        );
    }

    function test_sendMessageNotManager() public {
        uint16 chainId = 1;
        string memory chainName = "chainName";
        string memory axelarAddress = "axelarAddress";
        bytes32 recipientNttManagerAddress = bytes32(uint256(1010));
        bytes memory nttManagerMessage = bytes("nttManagerMessage");
        bytes32 refundAddress = bytes32(uint256(1011));
        TransceiverStructs.TransceiverInstruction memory instruction =
            TransceiverStructs.TransceiverInstruction(0, bytes(""));

        vm.prank(OWNER);
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("CallerNotNttManager(address)", OWNER));
        transceiver.sendMessage(
            chainId, instruction, nttManagerMessage, recipientNttManagerAddress, refundAddress
        );
    }

    function test_sendMessageChainNotRegisterred() public {
        uint16 chainId = 1;
        bytes32 recipientNttManagerAddress = bytes32(uint256(1010));
        bytes memory nttManagerMessage = bytes("nttManagerMessage");
        bytes32 refundAddress = bytes32(uint256(1011));
        TransceiverStructs.TransceiverInstruction memory instruction =
            TransceiverStructs.TransceiverInstruction(0, bytes(""));

        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSignature("InvalidChainId(uint16,string,string)", chainId, "", "")
        );
        transceiver.sendMessage(
            chainId, instruction, nttManagerMessage, recipientNttManagerAddress, refundAddress
        );
    }

    function test_transferTransceiverOwnership() public {
        address newOwner = address(1020);

        vm.prank(address(manager));
        transceiver.transferTransceiverOwnership(newOwner);
    }

    function test_transferTransceiverOwnershipNotManager() public {
        address newOwner = address(1020);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("CallerNotNttManager(address)", OWNER));
        transceiver.transferTransceiverOwnership(newOwner);
    }

    function test_execute() public {
        uint16 chainId = 2;
        string memory chainName = "chainName";
        string memory axelarAddress = "axelarAddress";
        bytes32 messageId = bytes32(uint256(25));
        bytes32 recipientNttManagerAddress = bytes32(uint256(uint160(address(manager))));

        bytes32 to = bytes32(uint256(1234));
        // Since our tokens have 18 decimals we need at least 10 zeros at the end to not lose precision.
        uint64 amount = 12345670000000000;
        bytes memory nttPayload;
        {
            bytes4 prefix = TransceiverStructs.NTT_PREFIX;
            uint8 decimals = 18;
            bytes32 sourceToken = bytes32(uint256(1022));
            uint16 toChain = 1;
            nttPayload = abi.encodePacked(prefix, decimals, amount, sourceToken, to, toChain);
        }

        bytes memory nttManagerMessage;
        {
            uint16 length = uint16(nttPayload.length);
            bytes32 nttMessageId = bytes32(uint256(0));
            bytes32 sender = bytes32(uint256(1));
            nttManagerMessage = abi.encodePacked(nttMessageId, sender, length, nttPayload);
        }

        bytes32 sourceNttManagerAddress = bytes32(uint256(1012));
        bytes memory payload =
            abi.encode(sourceNttManagerAddress, nttManagerMessage, recipientNttManagerAddress);

        vm.prank(OWNER);
        manager.setPeer(chainId, sourceNttManagerAddress, 8, 100000000);
        vm.prank(OWNER);
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);
        vm.prank(OWNER);
        token.setMinter(OWNER);
        vm.prank(OWNER);
        token.mint(address(manager), amount);
        gateway.approveContractCall(messageId, chainName, axelarAddress, keccak256(payload));

        transceiver.execute(messageId, chainName, axelarAddress, payload);

        if (token.balanceOf(fromWormholeFormat(to)) != amount) revert("Amount Incorrect");

        vm.prank(OWNER);
        token.mint(address(manager), amount);
        vm.expectRevert(abi.encodeWithSignature("NotApprovedByGateway()"));
        transceiver.execute(bytes32(0), chainName, axelarAddress, payload);
    }

    function test_executeNotTrustedAddress() public {
        string memory chainName = "chainName";
        string memory axelarAddress = "axelarAddress";
        bytes memory payload = bytes("");
        bytes32 messageId = keccak256(bytes("message Id"));
        gateway.approveContractCall(messageId, chainName, axelarAddress, keccak256(payload));
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidSibling(uint16,string,string)", 0, chainName, axelarAddress
            )
        );
        transceiver.execute(messageId, chainName, axelarAddress, payload);
    }
}
