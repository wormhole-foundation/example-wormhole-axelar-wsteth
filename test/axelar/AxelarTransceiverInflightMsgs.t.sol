// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "../../src/axelar/AxelarTransceiver.sol";
import "./mock/MockGatewayV2.sol";
import {MockAxelarGasService} from "./mock/MockGasService.sol";
import {TransceiverStructs} from
    "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";
import {NttManager} from "@wormhole-foundation/native_token_transfer/NttManager/NttManager.sol";
import {INttManager} from "@wormhole-foundation/native_token_transfer/interfaces/INttManager.sol";
import {IManagerBase} from "@wormhole-foundation/native_token_transfer/interfaces/IManagerBase.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {wstETHL2Token} from "../../src/token/wstETHL2Token.sol";

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract AxelarTransceiverInflightMessages is Test {
    address constant OWNER = address(1004);
    uint64 constant RATE_LIMIT_DURATION = 0;
    bool constant SKIP_RATE_LIMITING = true;

    uint256 constant DEVNET_GUARDIAN_PK =
        0xcfb12303a19cde580bb4dd771639b0d26bc68353645571a8cff516ab2ee113a0;

    AxelarTransceiver sourceTransceiver;
    IAxelarGateway gateway;
    IAxelarGasService gasService;
    NttManager sourceNttmanager;
    wstETHL2Token sourceToken;
    uint16 sourceChainId;

    AxelarTransceiver recipientTransceiver;
    NttManager recipientNttManager;
    wstETHL2Token recipientToken;
    uint16 recipientChainId;

    function setUp() public {
        gateway = IAxelarGateway(new MockAxelarGateway());
        gasService = IAxelarGasService(address(new MockAxelarGasService()));

        // Setup Source Infrastructure
        sourceChainId = 1;
        sourceToken = new wstETHL2Token("Wrapped StEth Source", "wStEthSrc", OWNER, OWNER);
        address sourceManagerImplementation = address(
            new NttManager(
                address(sourceToken),
                IManagerBase.Mode.LOCKING,
                sourceChainId,
                RATE_LIMIT_DURATION,
                SKIP_RATE_LIMITING
            )
        );
        sourceNttmanager = NttManager(address(new ERC1967Proxy(sourceManagerImplementation, "")));
        sourceNttmanager.initialize();
        sourceNttmanager.transferOwnership(OWNER);
        address srcTransceiverImplementation =
            address(new AxelarTransceiver(address(gateway), address(gasService), address(sourceNttmanager)));
        sourceTransceiver = AxelarTransceiver(address(new ERC1967Proxy(srcTransceiverImplementation, "")));
        sourceTransceiver.initialize();
        vm.prank(OWNER);
        sourceNttmanager.setTransceiver(address(sourceTransceiver));

        // Setup Recipient Infrastructure
        recipientChainId = 2;
        recipientToken = new wstETHL2Token("Wrapped StEth Recipient", "wStEthRcpt", OWNER, OWNER);
        address recipientManagerImplementation = address(
            new NttManager(
                address(recipientToken),
                IManagerBase.Mode.LOCKING,
                recipientChainId,
                RATE_LIMIT_DURATION,
                SKIP_RATE_LIMITING
            )
        );
        recipientNttManager = NttManager(address(new ERC1967Proxy(recipientManagerImplementation, "")));
        recipientNttManager.initialize();
        recipientNttManager.transferOwnership(OWNER);
        address rcptTransceiverImplementation =
            address(new AxelarTransceiver(address(gateway), address(gasService), address(recipientNttManager)));
        recipientTransceiver = AxelarTransceiver(address(new ERC1967Proxy(rcptTransceiverImplementation, "")));
        recipientTransceiver.initialize();
        vm.prank(OWNER);
        recipientNttManager.setTransceiver(address(recipientTransceiver)); 


        bytes32 sourceNttManagerAddress = bytes32(uint256(uint160(address(sourceNttmanager))));         
        bytes32 recipientNttManagerAddress = bytes32(uint256(uint160(address(recipientNttManager))));        

        // set peer ntt manager on source 
        vm.prank(OWNER);
        sourceNttmanager.setPeer(
            recipientChainId,
            recipientNttManagerAddress,
            18,
            100000000
        );

        // set peer ntt manager on recipient
        vm.prank(OWNER);
        recipientNttManager.setPeer(
            sourceChainId,
            sourceNttManagerAddress,
            18,
            100000000
        );        

        string memory sourceChainName = "srcChain";
        string memory sourceAxelarAddress = "srcAxelar";

        string memory recipientChainName = "recipientChain";
        string memory recipientAxelarAddress = "recipientAxelar";

        vm.prank(OWNER);
        sourceTransceiver.setAxelarChainId(recipientChainId, recipientChainName, recipientAxelarAddress);

        vm.prank(OWNER);
        recipientTransceiver.setAxelarChainId(sourceChainId, sourceChainName, sourceAxelarAddress);        

        // token mint source
        vm.prank(OWNER);
        sourceToken.mint(address(sourceNttmanager), 10e6 ether);

        vm.prank(OWNER);
        recipientToken.mint(address(recipientNttManager), 10e6 ether);

    }


    function testAxelarInflightMessages() public {
        bytes32 refundAddress = bytes32(uint256(1011));
        TransceiverStructs.TransceiverInstruction memory instruction =
            TransceiverStructs.TransceiverInstruction(0, bytes(""));

        // SEND MESSAGE ON SOURCE CHAIN
        bytes32 to = bytes32(uint256(1234));
        uint64 amount = 12345670000000000;
        bytes memory nttPayload;
        {
            bytes4 prefix = TransceiverStructs.NTT_PREFIX;
            uint8 decimals = 18;
            bytes32 srcToken = bytes32(uint256(uint160(address(sourceToken))));
            uint16 toChain = 2;
            nttPayload = abi.encodePacked(prefix, decimals, amount, srcToken, to, toChain);
        }

        bytes memory nttManagerMessage;
        {
            uint16 length = uint16(nttPayload.length);
            bytes32 messageId = bytes32(uint256(0));
            bytes32 sender = bytes32(uint256(1));
            nttManagerMessage = abi.encodePacked(messageId, sender, length, nttPayload);

        }
        bytes32 sourceNttManagerAddress = bytes32(uint256(uint160(address(sourceNttmanager))));         
        bytes32 recipientNttManagerAddress = bytes32(uint256(uint160(address(recipientNttManager))));        

        vm.prank(address(sourceNttmanager));
        sourceTransceiver.sendMessage(
            recipientChainId, instruction, nttManagerMessage, recipientNttManagerAddress, refundAddress
        );

        // APPROVE MESSAGE ON AXELAR GATEWAY

        IAxelarGateway.Message[] memory messages = new IAxelarGateway.Message[](1);
        messages[0] = IAxelarGateway.Message(
            "srcChain",
            "0",
            "srcAxelar",
            address(sourceNttmanager),
            keccak256(nttManagerMessage)
        );

        IAxelarGateway.WeightedSigner[] memory signers = new IAxelarGateway.WeightedSigner[](1);
        signers[0] = IAxelarGateway.WeightedSigner({
            signer: address(0xABC),
            weight: 1
        });

        // Dummy data for Proof
        IAxelarGateway.Proof memory proof = IAxelarGateway.Proof({
            signers: IAxelarGateway.WeightedSigners({
                signers: signers,
                threshold: 1,
                nonce: keccak256(abi.encodePacked("nonce"))
            }),
            signatures: new bytes[](1) 
        });
        proof.signatures[0] = hex"00";  // Dummy signature


        gateway.approveMessages(messages, proof);

        // CHANGE PEER ADDRESS
        string memory sourceChainName2 = "srcChain2";
        string memory sourceAxelarAddress2 = "srcAxelar2";

        // UPDATE THE PEER ADDRESS ON RECIPIENT CHAIN
        vm.prank(OWNER);
        recipientTransceiver.setAxelarChainId(sourceChainId, sourceChainName2, sourceAxelarAddress2);        
        
        // EXECUTE ON RECIPIENT CHAIN
        bytes memory payload = abi.encode(sourceNttManagerAddress, nttManagerMessage, recipientNttManagerAddress);
        
        vm.expectRevert(IAxelarGateway.NotApprovedByGateway.selector);
        recipientTransceiver.execute(bytes32(0), sourceChainName2, sourceAxelarAddress2, payload);
    }
}
