// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {
    StringToAddress, AddressToString
} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import {IEndpointManagerStandalone} from
    "@wormhole-foundation/native_token_transfer/interfaces/IEndpointManagerStandalone.sol";
import {EndpointStandalone} from "@wormhole-foundation/native_token_transfer/EndpointStandalone.sol";
import {EndpointStructs} from "@wormhole-foundation/native_token_transfer/libraries/EndpointStructs.sol";
import {SetEmitterMessage} from "./Structs.sol";
import {InterchainAddressTracker} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/InterchainAddressTracker.sol";

contract AxelarEndpoint is EndpointStandalone, AxelarExecutable, InterchainAddressTracker, Ownable {
    IAxelarGasService public immutable gasService;

    // keccak256('AxelarEndpoint.Slot') - 1
    bytes32 internal constant AXELAR_ENDPOINT_SLOT = 0x7b690f78e722b1536e4df559bd003eb9113b71df59901dd43b07ebc28ea586d8;

    struct AxelarEndpointStorage {    
        // These mappings are used to convert between chainId and chainName as Axelar accept chainName as string format
        mapping(uint16 => string) idToAxelarChainIds;
        mapping(string => uint16) axelarChainIdToId;
    }


    // Need to set this after testing for the actual gas limit on the destination chain.
    uint256 constant EXECUTION_GAS_LIMIT = 100000;

    error UnsupportedMessageType();
    error InvalidSibling(string sourceChain, string sourceAddress);
    error NotImplemented();

    modifier onlySibling(string calldata sourceChain, string calldata sourceAddress) {
        if (!isTrustedAddress(sourceChain, sourceAddress)) {
            revert InvalidSibling(sourceChain, sourceAddress);
        }
        _;
    }

    constructor(address _gateway, address _gasService, address _manager, address _owner)
        AxelarExecutable(_gateway)
        EndpointStandalone(_manager)
        Ownable(_owner)
    {
        gasService = IAxelarGasService(_gasService);
    }

    /**
     * Set the bridge manager contract address
     * @param chainId The chainId of the chain. This is used to identify the chain in the EndpointManager.
     * @param chainName The chainName of the chain. This is used to identify the chain in the AxelarGateway.
     */
    function setAxelarChainId(uint16 chainId, string calldata chainName, string calldata contractAddress) external onlyOwner {
        AxelarEndpointStorage storage slot = _axelarEndpointSlot();
        slot.idToAxelarChainIds[chainId] = chainName;
        slot.axelarChainIdToId[chainName] = chainId;
        _setTrustedAddress(chainName, contractAddress);
    }

    /**
     * Revert if the message type is not supported
     */
    function _handleMessage(bytes memory payload) internal returns (bool) {
        // Decode the payload as a EndpointManagerMessage
        EndpointStructs.EndpointManagerMessage memory message = EndpointStructs.parseEndpointManagerMessage(payload);

        // msgType 1: Send Token
        // msgType 2: Set Emitter (destination contract address)
        if (message.msgType == 1) {
            return false;
        } else {
            revert UnsupportedMessageType();
        }
    }

    /**
     * Send message to Axelar Gateway
     * @param recipientChain  The chainId of the chain. This is used to identify the chain in the EndpointManager.
     * @param payload The payload of the message which is a NativeTokenTransfer
     */
    function _sendMessage(uint16 recipientChain, bytes memory payload) internal virtual override {
        bool isInternalCall = _handleMessage(payload);

        if (isInternalCall) {
            return;
        }

        string memory destinationChain = _axelarEndpointSlot().idToAxelarChainIds[recipientChain];
        string memory destinationContract = trustedAddress(destinationChain);

        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this), destinationChain, destinationContract, payload, msg.sender
        );

        gateway.callContract(destinationChain, destinationContract, payload);
    }

    /**
     * Receive message from Axelar Gateway
     */
    function _execute(string calldata sourceChain, string calldata sourceAddress, bytes calldata payload)
        internal
        override
        onlySibling(sourceChain, sourceAddress)
    {
        EndpointStructs.EndpointManagerMessage memory message = EndpointStructs.parseEndpointManagerMessage(payload);
        IEndpointManagerStandalone(_manager).attestationReceived(message);
    }

    function _verifyMessage(bytes memory encodedMessage) internal override returns (bytes memory) {
        revert NotImplemented();
    }

    function _quoteDeliveryPrice(uint16 targetChain)
        internal
        view
        virtual
        override
        returns (uint256 nativePriceQuote)
    {
        // Axelar doesn't support on-chain gas fee.
        return gasService.estimateGasFee(
            _axelarEndpointSlot().idToAxelarChainIds[targetChain],
            '',
            '',
            EXECUTION_GAS_LIMIT,
            ''
        );
    }

    function idToAxelarChainIds(uint16 chainId) external returns (string memory chainName) {
        return _axelarEndpointSlot().idToAxelarChainIds[chainId];
    }

    function axelarChainIdToId(string calldata chainName) external returns (uint16 chainId) {
        return _axelarEndpointSlot().axelarChainIdToId[chainName];
    }

    /**
     * @notice Get the storage slot for the AxelarEndpointStorage struct
     */
    function _axelarEndpointSlot() private pure returns (AxelarEndpointStorage storage slot) {
        assembly {
            slot.slot := AXELAR_ENDPOINT_SLOT
        }
    }
}
