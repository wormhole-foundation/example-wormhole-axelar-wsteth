// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IEndpointManager} from "../../../src/axelar/interfaces/IEndpointManager.sol";

contract MockManager is IEndpointManager {
    function transfer(
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipient
    ) external override returns (uint64 msgId) {}

    function attestationReceived(bytes memory payload) external override {}

    function getThreshold() external view override returns (uint8) {}

    function getEndpoints() external view override returns (address[] memory) {}
}
