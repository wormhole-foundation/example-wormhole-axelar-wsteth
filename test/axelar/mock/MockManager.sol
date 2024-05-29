// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.22;

// import {IEndpointManagerStandalone} from "@wormhole-foundation/native_token_transfer/interfaces/IEndpointManagerStandalone.sol";
// import {EndpointStructs} from "@wormhole-foundation/native_token_transfer/libraries/EndpointStructs.sol";

// contract MockManager is IEndpointManagerStandalone {
//     function attestationReceived(EndpointStructs.EndpointManagerMessage memory payload) external override {}

//     function getThreshold() external view returns (uint8) {}

//     function getEndpoints() external view returns (address[] memory) {}

//     function transfer(
//         uint256 amount,
//         uint16 recipientChain,
//         bytes32 recipient
//     ) external payable returns (uint64 msgId) {}

//     function nextSequence() external view returns (uint64) {}
// }
