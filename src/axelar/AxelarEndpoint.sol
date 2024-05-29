// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
// import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
// import {
//     StringToAddress, AddressToString
// } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
// import {IEndpointManagerStandalone} from
//     "@wormhole-foundation/native_token_transfer/interfaces/IEndpointManagerStandalone.sol";
// import {EndpointStandalone} from "@wormhole-foundation/native_token_transfer/EndpointStandalone.sol";
// import {EndpointStructs} from "@wormhole-foundation/native_token_transfer/libraries/EndpointStructs.sol";
// import {SetEmitterMessage} from "./Structs.sol";

// contract AxelarEndpoint is EndpointStandalone, AxelarExecutable, Ownable {
//     IAxelarGasService public immutable gasService;

//     // These mappings are used to convert between chainId and chainName as Axelar accept chainName as string format
//     mapping(uint16 => string) public idToAxelarChainIds;
//     mapping(string => uint16) public axelarChainIdToId;

//     error UnsupportedMessageType();
//     error InvalidSibling(uint16 chainId, bytes32 siblingAddress);
//     error NotImplemented();

//     modifier onlySibling(string calldata sourceChain, string calldata sourceAddress) {
//         uint16 chainId = axelarChainIdToId[sourceChain];
//         address _sourceAddress = StringToAddress.toAddress(sourceAddress);
//         if (getSibling(chainId) != bytes32(uint256(uint160(_sourceAddress)))) {
//             revert InvalidSibling(chainId, getSibling(chainId));
//         }
//         _;
//     }

//     constructor(address _gateway, address _gasService, address _manager, address _owner)
//         AxelarExecutable(_gateway)
//         EndpointStandalone(_manager)
//         Ownable(_owner)
//     {
//         gasService = IAxelarGasService(_gasService);
//     }

//     /**
//      * Set the bridge manager contract address
//      * @param chainId The chainId of the chain. This is used to identify the chain in the EndpointManager.
//      * @param chainName The chainName of the chain. This is used to identify the chain in the AxelarGateway.
//      */
//     function setAxelarChainId(uint16 chainId, string calldata chainName) external onlyOwner {
//         idToAxelarChainIds[chainId] = chainName;
//         axelarChainIdToId[chainName] = chainId;
//     }

//     /**
//      * Revert if the message type is not supported
//      */
//     function _handleMessage(bytes memory payload) internal returns (bool) {
//         // Decode the payload as a EndpointManagerMessage
//         EndpointStructs.EndpointManagerMessage memory message = EndpointStructs.parseEndpointManagerMessage(payload);

//         // msgType 1: Send Token
//         // msgType 2: Set Emitter (destination contract address)
//         if (message.msgType == 1) {
//             return false;
//         } else {
//             revert UnsupportedMessageType();
//         }
//     }

//     /**
//      * Send message to Axelar Gateway
//      * @param recipientChain  The chainId of the chain. This is used to identify the chain in the EndpointManager.
//      * @param payload The payload of the message which is a NativeTokenTransfer
//      */
//     function _sendMessage(uint16 recipientChain, bytes memory payload) internal virtual override {
//         bool isInternalCall = _handleMessage(payload);

//         if (isInternalCall) {
//             return;
//         }

//         bytes32 destEmitter = getSibling(recipientChain);
//         string memory destinationContract = AddressToString.toString(address(uint160(uint256(destEmitter))));
//         string memory destinationChain = idToAxelarChainIds[recipientChain];

//         gasService.payNativeGasForContractCall{value: msg.value}(
//             address(this), destinationChain, destinationContract, payload, msg.sender
//         );

//         gateway.callContract(destinationChain, destinationContract, payload);
//     }

//     /**
//      * Receive message from Axelar Gateway
//      */
//     function _execute(string calldata sourceChain, string calldata sourceAddress, bytes calldata payload)
//         internal
//         override
//         onlySibling(sourceChain, sourceAddress)
//     {
//         EndpointStructs.EndpointManagerMessage memory message = EndpointStructs.parseEndpointManagerMessage(payload);
//         IEndpointManagerStandalone(_manager).attestationReceived(message);
//     }

//     function _verifyMessage(bytes memory encodedMessage) internal override returns (bytes memory) {
//         revert NotImplemented();
//     }

//     function _quoteDeliveryPrice(uint16 targetChain)
//         internal
//         view
//         virtual
//         override
//         returns (uint256 nativePriceQuote)
//     {
//         // Axelar doesn't support on-chain gas fee.
//         return 0;
//     }
// }
