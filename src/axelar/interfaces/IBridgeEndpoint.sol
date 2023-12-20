// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IBridgeEndpoint {
    error UnsupportedMessageType();

    function sendMessage(bytes memory payload) external payable;

    function getEmitter(uint16 chainId) external view returns (bytes32);
}
