// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "wormhole-solidity-sdk/Utils.sol";

import { TransceiverStructs } from "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";
import { INttManager } from "@wormhole-foundation/native_token_transfer/interfaces/INttManager.sol";

import { AxelarGMPExecutable } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarGMPExecutable.sol";
import { IAxelarGasService } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {
    StringToAddress, AddressToString
} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
// Use their libraries
import { Transceiver } from "@wormhole-foundation/native_token_transfer/Transceiver/Transceiver.sol";

import { IAxelarTransceiver } from './interfaces/IAxelarTransceiver.sol';

contract AxelarTransceiver is IAxelarTransceiver, AxelarGMPExecutable, Transceiver {
    IAxelarGasService public immutable gasService;

    // These mappings are used to convert chainId and chainName between Wormhole and Axelar formats.
    struct AxelarTransceiverStorage {
        mapping(uint16 => string) idToAxelarChainId;
        mapping(string => uint16) axelarChainIdToId;
        mapping(uint16 => string) idToTransceiverAddress;
        mapping(string => uint16) transceiverAddressToId;
    }
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.AxelarTransceiver")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant AXELAR_TRANSCEIVER_STORAGE_SLOT = 0x6d72a7741b755e11bdb1cef6ed3f290bbe196e69da228a3ae322e5bc37ea7600;

    // TODO: update this based on tests
    uint256 internal constant DESTINATION_EXECUTION_GAS_LIMIT = 200000;

    error UnsupportedMessageType();
    error InvalidSibling(uint16 chainId, string sourceChain, string sourceAddress);
    error NotImplemented();

    constructor(address _gateway, address _gasService, address _manager)
        AxelarGMPExecutable(_gateway)
        Transceiver(_manager)
    {
        gasService = IAxelarGasService(_gasService);
    }

    /**
     * Set the bridge manager contract address
     * @param chainId The chainId of the chain. This is used to identify the chain in the EndpointManager.
     * @param chainName The chainName of the chain. This is used to identify the chain in the AxelarGateway.
     * @param transceiverAddress The address of the tranceiver on the other chain, in the axelar accepted format.
     */
    function setAxelarChainId(uint16 chainId, string calldata chainName, string calldata transceiverAddress) external onlyOwner {
        AxelarTransceiverStorage storage slot = _storage();
        slot.idToAxelarChainId[chainId] = chainName;
        slot.axelarChainIdToId[chainName] = chainId;
        slot.idToTransceiverAddress[chainId] = transceiverAddress;
        slot.transceiverAddressToId[transceiverAddress] = chainId;
    }

    /// @notice Fetch the delivery price for a given recipient chain transfer.
    /// @param recipientChainId The Wormhole chain ID of the target chain.
    /// param instruction An additional Instruction provided by the Transceiver to be
    ///        executed on the recipient chain.
    /// @return deliveryPrice The cost of delivering a message to the recipient chain,
    ///         in this chain's native token.
    function _quoteDeliveryPrice(
        uint16 recipientChainId,
        TransceiverStructs.TransceiverInstruction memory /*instruction*/
    ) internal view override virtual returns (uint256) {
        // Use the gas estimation from gas service
        AxelarTransceiverStorage storage slot = _storage();
        return gasService.estimateGasFee(slot.idToAxelarChainId[recipientChainId], slot.idToTransceiverAddress[recipientChainId], bytes(''), DESTINATION_EXECUTION_GAS_LIMIT, bytes(''));
    }

    /// @dev Send a message to another chain.
    /// @param recipientChainId The Wormhole chain ID of the recipient.
    /// @param deliveryPayment the amount of native tokens to be used as gas for delivery.
    /// @param recipientNttManagerAddress the address of the NttManager to receive this message.
    /// @param refundAddress the address to receive the gas refund if overpayed.
    /// @param nttManagerMessage A message to be sent to the nttManager on the recipient chain.
    function _sendMessage(
        uint16 recipientChainId,
        uint256 deliveryPayment,
        address /*caller*/,
        bytes32 recipientNttManagerAddress,
        bytes32 refundAddress,
        TransceiverStructs.TransceiverInstruction memory /*transceiverInstruction*/,
        bytes memory nttManagerMessage
    ) internal override virtual onlyNttManager() {
        AxelarTransceiverStorage storage slot = _storage();
        string memory destinationContract = slot.idToTransceiverAddress[recipientChainId];
        string memory destinationChain = slot.idToAxelarChainId[recipientChainId];

        if (bytes(destinationChain).length == 0 || bytes(destinationContract).length == 0) revert InvalidChainId(recipientChainId);

        bytes memory payload = abi.encode(nttManager, nttManagerMessage, recipientNttManagerAddress);

        _callContract(destinationChain, destinationContract, payload, fromWormholeFormat(refundAddress), deliveryPayment);

        emit SendTransceiverMessage(recipientChainId, nttManagerMessage, recipientNttManagerAddress, refundAddress);
    }

    function _callContract(string memory destinationChain, string memory destinationContract, bytes memory payload, address refundAddress, uint256 deliveryPayment) internal virtual {
        gasService.payGas{value: deliveryPayment}(
           address(this), destinationChain, destinationContract, payload, 0, false, refundAddress, bytes('')
        );

        gateway().callContract(destinationChain, destinationContract, payload);
    }

    function _execute(
        bytes32 /*commandId*/,
        string calldata sourceChain, 
        string calldata sourceAddress, 
        bytes calldata payload
    ) internal override {
        AxelarTransceiverStorage storage slot = _storage();
        uint16 sourceChainId = slot.axelarChainIdToId[sourceChain];
        if (sourceChainId == 0 || slot.transceiverAddressToId[sourceAddress] != sourceChainId) {
            revert InvalidSibling(sourceChainId, sourceChain, sourceAddress);
        }

        (
            bytes32 sourceNttManagerAddress, 
            TransceiverStructs.NttManagerMessage memory nttManagerMessage,
            bytes32 recipientNttManagerAddress
        ) = abi.decode(payload, (bytes32, TransceiverStructs.NttManagerMessage, bytes32));

        _deliverToNttManager(
            sourceChainId,
            sourceNttManagerAddress,
            recipientNttManagerAddress,
            nttManagerMessage
        );
    }

    /**
     * @notice Get the storage slot for the AxelarTransceiverStorage struct
     */
    function _storage() private pure returns (AxelarTransceiverStorage storage slot) {
        assembly {
            slot.slot := AXELAR_TRANSCEIVER_STORAGE_SLOT
        }
    }
}