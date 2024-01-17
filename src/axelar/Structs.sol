// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

// SetEmitter payload corresponding to type == 2
struct SetEmitterMessage {
    /// @notice Chain ID of the emitter
    uint16 chainId;
    /// @notice Address of the emitter
    bytes32 bridgeContract;
}
