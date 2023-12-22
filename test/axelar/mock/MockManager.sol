// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IEndpointManager} from "@wormhole-foundation/native_token_transfer/interfaces/IEndpointManager.sol";

contract MockManager is IEndpointManager {
    function attestationReceived(bytes memory payload) external override {}

    function getThreshold() external view override returns (uint8) {}

    function getEndpoints() external view override returns (address[] memory) {}

    function transfer(
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipient
    ) external payable override returns (uint64 msgId) {}

    function nextSequence() external view override returns (uint64) {}
}
