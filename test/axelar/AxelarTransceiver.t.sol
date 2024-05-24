// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "../../src/axelar/AxelarTransceiver.sol";
import "../../src/axelar/AxelarTransceiverProxy.sol";
import "./mock/MockGateway.sol";
import { MockAxelarGasService } from "./mock/MockGasService.sol";
import { TransceiverStructs } from "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";


contract AxelarTransceiverTest is Test {
    address constant MANAGER = address(1003);
    address constant OWNER = address(1004);

    uint256 constant DEVNET_GUARDIAN_PK =
        0xcfb12303a19cde580bb4dd771639b0d26bc68353645571a8cff516ab2ee113a0;

    AxelarTransceiver transceiver;
    IAxelarGateway gateway;
    IAxelarGasService gasService;

    function setUp() public {
        string memory url = "https://ethereum-sepolia-rpc.publicnode.com";
        vm.createSelectFork(url);

        gateway = IAxelarGateway(new MockAxelarGateway());
        gasService = IAxelarGasService(address(new MockAxelarGasService()));
        AxelarTransceiver implementation = new AxelarTransceiver(address(gateway), address(gasService), MANAGER);
        AxelarTransceiverProxy proxy = new AxelarTransceiverProxy(address(implementation), OWNER, bytes(''));
        transceiver = AxelarTransceiver(address(proxy));
    }

    function test_setAxelarChainId() public {
        uint16 chainId = 1;
        string memory chainName = 'chainName';
        string memory axelarAddress = 'axelarAddress';
        
        vm.prank(OWNER);
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);
        assertEq(transceiver.idToAxelarChainIds(chainId), chainName);
        assertEq(transceiver.axelarChainIdToId(chainName),chainId);
        assertEq(transceiver.idToAxelarAddress(chainId), axelarAddress);
        assertEq(transceiver.axelarAddressToId(axelarAddress), chainId);
    }

    function testFail_setAxelarChainIdNotOwner() public {
        uint16 chainId = 1;
        string memory chainName = 'chainName';
        string memory axelarAddress = 'axelarAddress';
        
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);
    }

    function test_sendMessage() public {
        uint16 chainId = 1;
        string memory chainName = 'chainName';
        string memory axelarAddress = 'axelarAddress';
        bytes32 recipientNttManagerAddress = bytes32(uint256(1010));
        bytes memory nttManagerMessage = bytes('nttManagerMessage');
        bytes32 refundAddress = bytes32(uint256(1011));
        TransceiverStructs.TransceiverInstruction memory instruction = TransceiverStructs.TransceiverInstruction(0, bytes(''));

        vm.prank(OWNER);
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);
        vm.prank(MANAGER);
        transceiver.sendMessage(chainId, instruction, nttManagerMessage, recipientNttManagerAddress, refundAddress);
    }

    function testFail_sendMessageNotManager() public {
        uint16 chainId = 1;
        string memory chainName = 'chainName';
        string memory axelarAddress = 'axelarAddress';
        bytes32 recipientNttManagerAddress = bytes32(uint256(1010));
        bytes memory nttManagerMessage = bytes('nttManagerMessage');
        bytes32 refundAddress = bytes32(uint256(1011));
        TransceiverStructs.TransceiverInstruction memory instruction = TransceiverStructs.TransceiverInstruction(0, bytes(''));

        vm.prank(OWNER);
        transceiver.setAxelarChainId(chainId, chainName, axelarAddress);
        transceiver.sendMessage(chainId, instruction, nttManagerMessage, recipientNttManagerAddress, refundAddress);
    }

    function testFail_sendMessageChainNotRegisterred() public {
        uint16 chainId = 1;
        bytes32 recipientNttManagerAddress = bytes32(uint256(1010));
        bytes memory nttManagerMessage = bytes('nttManagerMessage');
        bytes32 refundAddress = bytes32(uint256(1011));
        TransceiverStructs.TransceiverInstruction memory instruction = TransceiverStructs.TransceiverInstruction(0, bytes(''));

        vm.prank(MANAGER);
        transceiver.sendMessage(chainId, instruction, nttManagerMessage, recipientNttManagerAddress, refundAddress);
    }

    function test_transferTransceiverOwnership() public {
        address newOwner = address(1020);

        vm.prank(MANAGER);
        transceiver.transferTransceiverOwnership(newOwner);
    }

    function testFail_transferTransceiverOwnershipNotManager() public {
        address newOwner = address(1020);

        vm.prank(Owner);
        transceiver.transferTransceiverOwnership(newOwner);
    }
}