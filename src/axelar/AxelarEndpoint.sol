// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/Ownable.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {StringToBytes32, Bytes32ToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/Bytes32String.sol";
import {Endpoint} from "./Endpoint.sol";
import {IBridgeManager} from "./interfaces/IBridgeManager.sol";
import {EndpointManagerMessage, NativeTokenTransfer} from "./Message.sol";

contract AxelarEndpoint is Endpoint, AxelarExecutable, Ownable {
    IAxelarGasService public immutable gasService;
    IBridgeManager public endpointManager;

    // These mappings are used to convert between chainId and chainName as Axelar accept chainName as string format
    mapping(uint16 => string) public idToAxelarChainIds;
    mapping(string => uint16) public axelarChainIdToId;

    modifier onlySourceEmitter(
        string calldata sourceAddress,
        string calldata sourceChain
    ) {
        uint16 chainId = axelarChainIdToId[sourceChain];
        require(
            emitters[chainId] == StringToBytes32.toBytes32(sourceAddress),
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
        endpointManager = IBridgeManager(_bridgeManager);
    }

    /**
     * Set the bridge manager contract address
     * @param chainId The chainId of the chain. This is used to identify the chain in the EndpointManager.
     * @param chainName The chainName of the chain. This is used to identify the chain in the AxelarGateway.
     */
    function setAxelarChainId(
        uint16 chainId,
        string calldata chainName
    ) external onlyOwner {
        idToAxelarChainIds[chainId] = chainName;
        axelarChainIdToId[chainName] = chainId;
    }

    /**
     * Revert if the message type is not supported
     */
    function revertIfInvalidMessageType(bytes memory payload) internal pure {
        // Decode the payload as a BridgeManagerMessage
        EndpointManagerMessage memory message = abi.decode(
            payload,
            (EndpointManagerMessage)
        );

        // This contract only supports message type 1 which is a NativeTokenTransfer.
        if (message.msgType != 1) {
            revert UnsupportedMessageType();
        }
    }

    /**
     * Send message to Axelar Gateway
     * @param recipientChain  The chainId of the chain. This is used to identify the chain in the EndpointManager.
     * @param payload The payload of the message which is a NativeTokenTransfer
     */
    function _sendMessage(
        uint16 recipientChain,
        bytes memory payload
    ) internal virtual override {
        revertIfInvalidMessageType(payload);

        string memory destinationContract = Bytes32ToString.toTrimmedString(
            emitters[recipientChain]
        );
        string memory destinationChain = idToAxelarChainIds[recipientChain];

        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this),
            destinationChain,
            destinationContract,
            payload,
            msg.sender
        );

        gateway.callContract(destinationChain, destinationContract, payload);
    }

    /**
     * Receive message from Axelar Gateway
     */
    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override onlySourceEmitter(sourceAddress, sourceChain) {
        endpointManager.attestationReceived(payload);
    }

    function receiveMessage(
        bytes memory encodedMessage
    ) external virtual override {
        // Won't be implemented for Axelar.
        // Axelar has defined different function for receive a message from the relayer which is the function called `_execute` above.
    }
}
