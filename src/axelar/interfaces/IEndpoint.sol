// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IEndpoint {
    error UnsupportedMessageType();

    event EmitterSet(uint16 chainId, bytes32 bridgeContract);

    function sendMessage(
        uint16 recipientChain,
        bytes memory payload
    ) external payable;

    function getEmitter(uint16 chainId) external view returns (bytes32);
}
