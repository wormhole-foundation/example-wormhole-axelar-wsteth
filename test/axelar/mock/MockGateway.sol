// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IAxelarGateway {
    event ContractCall(
        address indexed sender,
        string destinationChain,
        string destinationContractAddress,
        bytes32 indexed payloadHash,
        bytes payload
    );

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

    function approveContractCall(
        bytes32 messageId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) external;
}

contract MockAxelarGateway is IAxelarGateway {
    mapping(bytes32 => bool) approved;

    function callContract(
        string calldata destinationChain,
        string calldata destinationContractAddress,
        bytes calldata payload
    ) external override {
        emit ContractCall(
            msg.sender, destinationChain, destinationContractAddress, keccak256(payload), payload
        );
    }

    function _getContractCallKey(
        bytes32 messageId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(messageId, sourceChain, sourceAddress, payloadHash));
    }

    function approveContractCall(
        bytes32 messageId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) external {
        approved[_getContractCallKey(messageId, sourceChain, sourceAddress, payloadHash)] = true;
    }

    function validateContractCall(
        bytes32 messageId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) external override returns (bool) {
        bytes32 key = _getContractCallKey(messageId, sourceChain, sourceAddress, payloadHash);
        bool messageApproved = approved[key];
        if (messageApproved) approved[key] = false;
        return messageApproved;
    }
}
