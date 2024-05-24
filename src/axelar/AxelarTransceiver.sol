// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "wormhole-solidity-sdk/Utils.sol";

import { TransceiverStructs } from "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";
import { INttManager } from "@wormhole-foundation/native_token_transfer/interfaces/INttManager.sol";

import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {
    StringToAddress, AddressToString
} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import { Upgradable } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/upgradable/Upgradable.sol";

import {Managed} from "./utils/Managed.sol";
import { IAxelarTransceiver } from './interfaces/IAxelarTransceiver.sol';

contract AxelarTransceiver is IAxelarTransceiver, AxelarExecutable, Managed, Upgradable {
    IAxelarGasService public immutable gasService;

    // These mappings are used to convert between chainId and chainName as Axelar accept chainName as string format
    mapping(uint16 => string) public idToAxelarChainIds;
    mapping(string => uint16) public axelarChainIdToId;
    mapping(uint16 => string) public idToAxelarAddress;
    mapping(string => uint16) public axelarAddressToId;

    error UnsupportedMessageType();
    error InvalidSibling(uint16 chainId, string sourceChain, string sourceAddress);
    error NotImplemented();

    constructor(address _gateway, address _gasService, address _manager)
        AxelarExecutable(_gateway)
        Managed(_manager)
    {
        gasService = IAxelarGasService(_gasService);
    }

    function _setup(bytes calldata params) internal override {
    }

    function contractId() external pure override returns (bytes32) {
        return keccak256('axelar-transceiver');
    }

    /**
     * Set the bridge manager contract address
     * @param chainId The chainId of the chain. This is used to identify the chain in the EndpointManager.
     * @param chainName The chainName of the chain. This is used to identify the chain in the AxelarGateway.
     */
    function setAxelarChainId(uint16 chainId, string calldata chainName, string calldata axelarAddress) external onlyOwner {
        idToAxelarChainIds[chainId] = chainName;
        axelarChainIdToId[chainName] = chainId;
        idToAxelarAddress[chainId] = axelarAddress;
        axelarAddressToId[axelarAddress] = chainId;
    }

    /// @notice Fetch the delivery price for a given recipient chain transfer.
    /// param recipientChain The Wormhole chain ID of the target chain.
    /// param instruction An additional Instruction provided by the Transceiver to be
    ///        executed on the recipient chain.
    /// @return deliveryPrice The cost of delivering a message to the recipient chain,
    ///         in this chain's native token.
    function quoteDeliveryPrice(
        uint16 /*recipientChain*/,
        TransceiverStructs.TransceiverInstruction memory /*instruction*/
    ) external view override virtual returns (uint256) {
        // Axelar doesn't support on-chain gas fee.
        return 0;
    }

    /// @dev Send a message to another chain.
    /// @param recipientChainId The Wormhole chain ID of the recipient.
    /// param instruction An additional Instruction provided by the Transceiver to be
    /// executed on the recipient chain.
    /// @param nttManagerMessage A message to be sent to the nttManager on the recipient chain.
    function sendMessage(
        uint16 recipientChainId,
        TransceiverStructs.TransceiverInstruction memory /*instruction*/,
        bytes memory nttManagerMessage,
        bytes32 recipientNttManagerAddress,
        bytes32 refundAddress
    ) external payable override virtual onlyManager() {
        emit SendTransceiverMessage(recipientChainId, nttManagerMessage, recipientNttManagerAddress, refundAddress);

        string memory destinationContract = idToAxelarAddress[recipientChainId];
        string memory destinationChain = idToAxelarChainIds[recipientChainId];

        if(bytes(destinationChain).length == 0 || bytes(destinationContract).length == 0) revert InvalidChainId(recipientChainId);

        bytes memory payload = abi.encode(manager, nttManagerMessage, recipientNttManagerAddress);

        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this), destinationChain, destinationContract, payload, fromWormholeFormat(refundAddress)
        );

        gateway.callContract(destinationChain, destinationContract, payload);
    }

    /// @notice Upgrades the transceiver to a new implementation.
    function upgrade(address newImplementation) external override virtual onlyOwner() {

    }

    /// @notice Transfers the ownership of the transceiver to a new address.
    function transferTransceiverOwnership(address newOwner) external override virtual onlyManager() {
        _transferOwnership(newOwner);
    }

    function _execute(string calldata sourceChain, string calldata sourceAddress, bytes calldata payload) internal override {
        uint16 sourceChainId = axelarChainIdToId[sourceChain];
        if (sourceChainId == 0 || axelarAddressToId[sourceAddress] != sourceChainId) {
            revert InvalidSibling(sourceChainId, sourceChain, sourceAddress);
        }

        (
            bytes32 sourceNttManagerAddress, 
            TransceiverStructs.NttManagerMessage memory nttManagerMessage,
            bytes32 recipientNttManagerAddress
        ) = abi.decode(payload, (bytes32, TransceiverStructs.NttManagerMessage, bytes32));

        if (recipientNttManagerAddress != toWormholeFormat(manager)) {
            revert UnexpectedRecipientNttManagerAddress(
                toWormholeFormat(manager), recipientNttManagerAddress
            );
        }
        INttManager(manager).attestationReceived(sourceChainId, sourceNttManagerAddress, nttManagerMessage);
    }
}