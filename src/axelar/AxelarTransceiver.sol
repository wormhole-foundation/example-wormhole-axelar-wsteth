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
// Use their libraries
import { Transceiver } from "@wormhole-foundation/native_token_transfer/Transceiver/Transceiver.sol";

import { IAxelarTransceiver } from './interfaces/IAxelarTransceiver.sol';

contract AxelarTransceiver is IAxelarTransceiver, AxelarExecutable, Transceiver {
    IAxelarGasService public immutable gasService;

    // These mappings are used to convert between chainId and chainName as Axelar accept chainName as string format
    struct AxelarTransceiverStorage {
        mapping(uint16 => string) idToAxelarChainIds;
        mapping(string => uint16) axelarChainIdToId;
        mapping(uint16 => string) idToAxelarAddress;
        mapping(string => uint16) axelarAddressToId;
    }

    // keccak256('AxelarTransceiver.Slot') - 1
    bytes32 internal constant AXELAR_TRANSCEIVER_STORAGE_SLOT = 0x16cc7b9f29b247db6f6c7350203c763b8802896c91208a944bb4707de3f359a6;

    error UnsupportedMessageType();
    error InvalidSibling(uint16 chainId, string sourceChain, string sourceAddress);
    error NotImplemented();

    constructor(address _gateway, address _gasService, address _manager)
        AxelarExecutable(_gateway)
        Transceiver(_manager)
    {
        gasService = IAxelarGasService(_gasService);
    }

    /**
     * Set the bridge manager contract address
     * @param chainId The chainId of the chain. This is used to identify the chain in the EndpointManager.
     * @param chainName The chainName of the chain. This is used to identify the chain in the AxelarGateway.
     */
    function setAxelarChainId(uint16 chainId, string calldata chainName, string calldata axelarAddress) external onlyOwner {
        AxelarTransceiverStorage storage slot = _storage();
        slot.idToAxelarChainIds[chainId] = chainName;
        slot.axelarChainIdToId[chainName] = chainId;
        slot.idToAxelarAddress[chainId] = axelarAddress;
        slot.axelarAddressToId[axelarAddress] = chainId;
    }

    /// @notice Fetch the delivery price for a given recipient chain transfer.
    /// param recipientChain The Wormhole chain ID of the target chain.
    /// param instruction An additional Instruction provided by the Transceiver to be
    ///        executed on the recipient chain.
    /// @return deliveryPrice The cost of delivering a message to the recipient chain,
    ///         in this chain's native token.
    function _quoteDeliveryPrice(
        uint16 /*recipientChain*/,
        TransceiverStructs.TransceiverInstruction memory /*instruction*/
    ) internal view override virtual returns (uint256) {
        // Use the gas estimation from gas service
        return 0;
    }

    /// @dev Send a message to another chain.
    /// @param recipientChainId The Wormhole chain ID of the recipient.
    /// param instruction An additional Instruction provided by the Transceiver to be
    /// executed on the recipient chain.
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
        emit SendTransceiverMessage(recipientChainId, nttManagerMessage, recipientNttManagerAddress, refundAddress);

        AxelarTransceiverStorage storage slot = _storage();
        string memory destinationContract = slot.idToAxelarAddress[recipientChainId];
        string memory destinationChain = slot.idToAxelarChainIds[recipientChainId];

        if(bytes(destinationChain).length == 0 || bytes(destinationContract).length == 0) revert InvalidChainId(recipientChainId);

        bytes memory payload = abi.encode(nttManager, nttManagerMessage, recipientNttManagerAddress);

        gasService.payNativeGasForContractCall{value: deliveryPayment}(
            address(this), destinationChain, destinationContract, payload, fromWormholeFormat(refundAddress)
        );

        gateway.callContract(destinationChain, destinationContract, payload);
    }

    function _execute(string calldata sourceChain, string calldata sourceAddress, bytes calldata payload) internal override {
        AxelarTransceiverStorage storage slot = _storage();
        uint16 sourceChainId = slot.axelarChainIdToId[sourceChain];
        if (sourceChainId == 0 || slot.axelarAddressToId[sourceAddress] != sourceChainId) {
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