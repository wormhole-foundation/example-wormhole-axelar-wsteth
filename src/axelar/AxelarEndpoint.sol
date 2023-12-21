// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/Ownable.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {Endpoint} from "./Endpoint.sol";
import {IBridgeManager} from "./interfaces/IBridgeManager.sol";
import {EndpointManagerMessage, NativeTokenTransfer} from "./Message.sol";

contract AxelarEndpoint is Endpoint, AxelarExecutable, Ownable {
    IAxelarGasService public immutable gasService;
    IBridgeManager public bridgeManager;

    // These mappings are used to convert between chainId and chainName as Axelar accept chainName as string format
    mapping(uint16 => string) public idToAxelarChainIds;
    mapping(string => uint16) public axelarChainIdToId;

    modifier onlySourceEmitter(
        string calldata sourceAddress,
        string calldata sourceChain
    ) {
        uint16 chainId = axelarChainIdToId[sourceChain];
        require(
            emitters[chainId] == keccak256(abi.encodePacked(sourceAddress)),
            "Caller is not the source emitter"
        );
        _;
    }

    constructor(
        address _gateway,
        address _gasService,
        address _bridgeManager,
        address _owner
    ) AxelarExecutable(_gateway) Ownable(_owner) {
        gasService = IAxelarGasService(_gasService);
        bridgeManager = IBridgeManager(_bridgeManager);
    }

    function setAxelarChainId(
        uint16 chainId,
        string calldata chainName
    ) external onlyOwner {
        idToAxelarChainIds[chainId] = chainName;
        axelarChainIdToId[chainName] = chainId;
    }

    function parseEndpointManagerMessage(
        bytes memory payload
    ) internal view returns (string memory, bytes memory) {
        // Decode the payload as a BridgeManagerMessage
        EndpointManagerMessage memory message = abi.decode(
            payload,
            (EndpointManagerMessage)
        );

        // Check that the message is a token transfer
        if (message.msgType == 1) {
            NativeTokenTransfer memory msgTokenTransfer = abi.decode(
                message.payload,
                (NativeTokenTransfer)
            );

            // Returns destinationChain and destinationContract in a tuple of strings so that compatibles with AxelarGateway's callContract.
            return (
                string(abi.encodePacked(emitters[msgTokenTransfer.toChain])),
                message.payload
            );
        }

        revert UnsupportedMessageType();
    }

    function _sendMessage(
        uint16 recipientChain,
        bytes memory payload
    ) internal virtual override {
        (
            string memory destinationContract,
            bytes memory _payload
        ) = parseEndpointManagerMessage(payload);

        string memory destinationChain = idToAxelarChainIds[recipientChain];

        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this),
            destinationChain,
            destinationContract,
            _payload,
            msg.sender
        );

        gateway.callContract(destinationChain, destinationContract, _payload);
    }

    /**
     * Receive message from Axelar Gateway
     */
    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override onlySourceEmitter(sourceAddress, sourceChain) {
        bridgeManager.attestationReceived(payload);
    }

    function receiveMessage(
        bytes memory encodedMessage
    ) external virtual override {
        // Won't be implemented for Axelar.
        // Axelar has defined different function for receive a message from the relayer which is the function called `_execute` above.
    }
}
