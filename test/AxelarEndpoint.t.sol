// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {AxelarEndpoint} from "../src/axelar/AxelarEndpoint.sol";
import {MockAxelarGateway} from "./axelar/mock/MockGateway.sol";
import {MockManager} from "./axelar/mock/MockManager.sol";
import {StringToBytes32, Bytes32ToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/Bytes32String.sol";
import {AddressToString, StringToAddress} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import {EndpointStructs} from "@wormhole-foundation/native_token_transfer/libraries/EndpointStructs.sol";
import {SetEmitterMessage} from "../src/axelar/Structs.sol";

contract AxelarEndpointTest is Test {
    address constant GAS_SERVICE = address(1003);
    address constant MANAGER = address(1003);
    address constant OWNER = address(1004);
    AxelarEndpoint public endpoint;
    MockAxelarGateway public mockGateway;
    MockManager public mockManager;

    function setUp() public {
        mockGateway = new MockAxelarGateway();
        mockManager = new MockManager();
        endpoint = new AxelarEndpoint(
            address(mockGateway),
            GAS_SERVICE,
            address(mockManager),
            OWNER
        );
    }

    function test_setAxelarChainId() public {
        vm.prank(OWNER);
        endpoint.setAxelarChainId(1, "chain1", "0x1234");
        assertEq(endpoint.idToAxelarChainIds(1), "chain1");
        assertEq(endpoint.axelarChainIdToId("chain1"), 1);
    }

    function testFail_execute_sourceAddressIsNotSourceEmitter() public {
        endpoint.execute(
            "commandId",
            "sourceChain",
            "sourceAddress",
            "payload"
        );
    }

    function test_execute_callerIsValidSourceEmitter() public {
        vm.prank(OWNER);
        address SOURCE_CONTRACT = address(11111);
        endpoint.setAxelarChainId(1, "sourceChain1", AddressToString.toString(SOURCE_CONTRACT));

        endpoint.execute(
            "commandId",
            "sourceChain1",
            AddressToString.toString(SOURCE_CONTRACT),
            "payload"
        );
    }

    function test_bytes32Address() public {
        address testAddress = address(11111);
        bytes32 bytes32SourceContract = bytes32(uint256(uint160(testAddress)));
        address convertedAddress = address(
            uint160(uint256(bytes32SourceContract))
        );

        assertEq(testAddress, convertedAddress);
    }

    function test_AddressString() public {
        address testAddress = address(11111);
        string memory stringAddress = AddressToString.toString(testAddress);
        address convertedAddress = StringToAddress.toAddress(stringAddress);

        assertEq(testAddress, convertedAddress);
    }
}
