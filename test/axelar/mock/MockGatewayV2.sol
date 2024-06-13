// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IAxelarGateway {

    error InvalidMessages();
    error NotApprovedByGateway();

    struct Message {
        string sourceChain;
        string messageId;
        string sourceAddress;
        address contractAddress;
        bytes32 payloadHash;
    }

    struct WeightedSigner {
        address signer;
        uint128 weight;
    }

    struct WeightedSigners {
        WeightedSigner[] signers;
        uint128 threshold;
        bytes32 nonce;
    }

    struct Proof {
        WeightedSigners signers;
        bytes[] signatures;
    }

    event MessageApproved(
        bytes32 indexed commandId,
        string sourceChain,
        string messageId,
        string sourceAddress,
        address indexed contractAddress,
        bytes32 indexed payloadHash
    );

    event MessageExecuted(bytes32 indexed commandId);            

    struct BaseAmplifierGatewayStorage {
        mapping(bytes32 => bytes32) messages;
    }

    function validateContractCall(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) external returns (bool);

    function callContract(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload
    ) external;

    function approveMessages(Message[] calldata messages, Proof calldata ) external ;

}

contract MockAxelarGateway is IAxelarGateway {

    /// @dev This slot contains the storage for this contract in an upgrade-compatible manner
    /// keccak256('BaseAmplifierGateway.Slot') - 1;
    bytes32 internal constant BASE_AMPLIFIER_GATEWAY_SLOT =
        0x978b1ab9e384397ce0aab28eec0e3c25603b3210984045ad0e0f0a50d88cfc55;

    bytes32 internal constant MESSAGE_NONEXISTENT = 0;
    bytes32 internal constant MESSAGE_EXECUTED = bytes32(uint256(1));    

    function messageToCommandId(string calldata sourceChain, string calldata messageId) public pure returns (bytes32) {
        // Axelar doesn't allow `sourceChain` to contain '_', hence this encoding is umambiguous
        return keccak256(bytes(string.concat(sourceChain, '_', messageId)));
    }

    function _messageHash(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        address contractAddress,
        bytes32 payloadHash
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(commandId, sourceChain, sourceAddress, contractAddress, payloadHash));
    }

    //@audit @note assume proof is always valid
    function approveMessages(Message[] calldata messages, Proof calldata ) external {
    //bytes32 dataHash = keccak256(abi.encode(CommandType.ApproveMessages, messages));
    // _validateProof(dataHash, proof);
   
        _approveMessages(messages);
    }

    function _approveMessages(Message[] calldata messages) internal {
        uint256 length = messages.length;
        if (length == 0) revert InvalidMessages();

        for (uint256 i; i < length; ++i) {
            // Ignores message if it has already been approved before
            _approveMessage(messages[i]);
        }
    }

    function _approveMessage(Message calldata message) internal {
        // For other implementations, `sourceChain` and `messageId` tuple could be used as the mapping key directly.
        bytes32 commandId = messageToCommandId(message.sourceChain, message.messageId);

        // Ignore if message has already been approved/executed
        if (_baseAmplifierGatewayStorage().messages[commandId] != MESSAGE_NONEXISTENT) {
            return;
        }

        bytes32 messageHash = _messageHash(
            commandId,
            message.sourceChain,
            message.sourceAddress,
            message.contractAddress,
            message.payloadHash
        );
        _baseAmplifierGatewayStorage().messages[commandId] = messageHash;

        emit MessageApproved(
            commandId,
            message.sourceChain,
            message.messageId,
            message.sourceAddress,
            message.contractAddress,
            message.payloadHash
        );
    }

    function callContract(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload
    ) external override {}

    function validateContractCall(
    bytes32 commandId,
    string calldata sourceChain,
    string calldata sourceAddress,
    bytes32 payloadHash
    ) external override returns (bool) {
        return _validateMessage(commandId, sourceChain, sourceAddress, payloadHash);
    }

    function _validateMessage(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) internal returns (bool valid) {
        bytes32 messageHash = _messageHash(commandId, sourceChain, sourceAddress, msg.sender, payloadHash);
        valid = _baseAmplifierGatewayStorage().messages[commandId] == messageHash;

        if (valid) {
            _baseAmplifierGatewayStorage().messages[commandId] = MESSAGE_EXECUTED;

            emit MessageExecuted(commandId);
        }
    }    

    function _baseAmplifierGatewayStorage() private pure returns (BaseAmplifierGatewayStorage storage slot) {
        assembly {
            slot.slot := BASE_AMPLIFIER_GATEWAY_SLOT
        }
    }    
}
