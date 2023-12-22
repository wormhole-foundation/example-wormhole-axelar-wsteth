// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/Ownable.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {StringToAddress, AddressToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import {IEndpointManager} from "@wormhole-foundation/native_token_transfer/interfaces/IEndpointManager.sol";
import {Endpoint} from "@wormhole-foundation/native_token_transfer/Endpoint.sol";
import {EndpointManagerMessage, NativeTokenTransfer} from "@wormhole-foundation/native_token_transfer/EndpointStructs.sol";
import {SetEmitterMessage} from "./Structs.sol";

contract AxelarEndpoint is Endpoint, AxelarExecutable, Ownable {
    IAxelarGasService public immutable gasService;

    // These mappings are used to convert between chainId and chainName as Axelar accept chainName as string format
    mapping(uint16 => string) public idToAxelarChainIds;
    mapping(string => uint16) public axelarChainIdToId;

    error UnsupportedMessageType();

    modifier onlySourceEmitter(
        string calldata sourceChain,
        string calldata sourceAddress
    ) {
        uint16 chainId = axelarChainIdToId[sourceChain];
        address _sourceAddress = StringToAddress.toAddress(sourceAddress);
        require(
            emitters[chainId] == bytes32(uint256(uint160(_sourceAddress))),
            "Caller is not the source emitter"
        );
        _;
    }

    constructor(
        address _gateway,
        address _gasService,
        address _manager,
        address _owner
    ) AxelarExecutable(_gateway) Ownable(_owner) {
        gasService = IAxelarGasService(_gasService);
        manager = _manager;
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
    function _handleMessage(bytes memory payload) internal returns (bool) {
        // Decode the payload as a EndpointManagerMessage
        EndpointManagerMessage memory message = abi.decode(
            payload,
            (EndpointManagerMessage)
        );

        // This contract only supports message type 1 which is a NativeTokenTransfer.
        if (message.msgType == 1) {
            // do nothing
            return false;
        } else if (message.msgType == 2) {
            // setEmitter
            SetEmitterMessage memory setEmitterMsg = abi.decode(
                message.payload,
                (SetEmitterMessage)
            );

            setEmitter(setEmitterMsg.chainId, setEmitterMsg.bridgeContract);

            return true;
        } else {
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
        bool isInternalCall = _handleMessage(payload);

        if (isInternalCall) {
            return;
        }

        bytes32 destEmitter = emitters[recipientChain];
        string memory destinationContract = AddressToString.toString(
            address(uint160(uint256(destEmitter)))
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
    ) internal override onlySourceEmitter(sourceChain, sourceAddress) {
        IEndpointManager(manager).attestationReceived(payload);
    }

    function receiveMessage(
        bytes memory encodedMessage
    ) external virtual override {
        // Won't be implemented for Axelar.
        // Axelar has defined different function for receive a message from the relayer which is the function called `_execute` above.
    }

    function getEmitters() external view override returns (bytes32[] memory) {
        // Not implemented
    }
}
