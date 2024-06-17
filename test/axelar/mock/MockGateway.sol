// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IAxelarGateway {
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
}

contract MockAxelarGateway is IAxelarGateway {
    function callContract(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload
    ) external override {}

    function validateContractCall(
        bytes32,
        string memory,
        string memory,
        bytes32
    ) external pure override returns (bool) {
        return true;
    }
}
