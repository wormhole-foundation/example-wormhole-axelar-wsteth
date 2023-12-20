// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/Ownable.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {IBridgeEndpoint} from "./interfaces/IBridgeEndpoint.sol";
import {IBridgeManager} from "./interfaces/IBridgeManager.sol";
import {BridgeManagerMessage, MultiBridgeTokenTransfer} from "./Message.sol";

contract AxelarEndpoint is IBridgeEndpoint, AxelarExecutable, Ownable {
    IAxelarGasService public immutable gasService;
    IBridgeManager public bridgeManager;

    // These mappings are used to convert between chainId and chainName as Axelar accept chainName as string format
    mapping(uint16 => string) public idToAxelarChainIds;
    mapping(string => uint16) public axelarChainIdToId;

    mapping(uint16 => bytes32) private emitters;

    modifier onlyManager() {
        require(
            msg.sender == address(bridgeManager),
            "Caller is not the BridgeManager"
        );
        _;
    }

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

    /**
     * Send message to Axelar Gateway
     */
    function sendMessage(bytes memory payload) external payable onlyManager {
        (
            string memory destinationChain,
            string memory destinationContract,
            bytes memory _payload
        ) = parseBridgeManagerMessage(payload);

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

    /**
     * @notice Set the emitter for a given chainId
     */
    function setEmitter(
        uint16 chainId,
        bytes32 emitter
    ) external onlyOwner {
        emitters[chainId] = emitter;
    }

    function transferBridgeManager(address target) external onlyManager {
        bridgeManager = IBridgeManager(target);
    }

    /**
     * @notice Get corresponding chainId for a given destination chainId
     */
    function getEmitter(uint16 chainId) external view returns (bytes32) {
        return emitters[chainId];
    }

    function parseBridgeManagerMessage(
        bytes memory payload
    ) internal view returns (string memory, string memory, bytes memory) {
        // Decode the payload as a BridgeManagerMessage
        BridgeManagerMessage memory message = abi.decode(
            payload,
            (BridgeManagerMessage)
        );

        // Check that the message is a token transfer
        if (message.msgType == 1) {
            MultiBridgeTokenTransfer memory msgTokenTransfer = abi.decode(
                message.payload,
                (MultiBridgeTokenTransfer)
            );

            // Returns destinationChain and destinationContract in a tuple of strings so that compatibles with AxelarGateway's callContract.
            return (
                idToAxelarChainIds[msgTokenTransfer.toChain],
                string(abi.encodePacked(emitters[msgTokenTransfer.toChain])),
                message.payload
            );
        }

        revert UnsupportedMessageType();
    }
}
