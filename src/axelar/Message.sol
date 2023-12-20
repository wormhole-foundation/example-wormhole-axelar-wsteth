// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

struct BridgeManagerMessage {
    /// @notice unique sequence number
    uint64 id;
    /// @notice type of the message, which determines how the payload should be decoded.
    uint8 msgType;
    /// @notice payload that corresponds to the type.
    bytes payload;
}

struct MultiBridgeTokenTransfer {
    /// @notice Amount being transferred (big-endian uint256)
    uint256 amount;
    /// @notice Address of the token. Left-zero-padded if shorter than 32 bytes
    bytes32 tokenAddress;
    /// @notice Address of the recipient. Left-zero-padded if shorter than 32 bytes
    bytes32 to;
    /// @notice Chain ID of the recipient
    uint16 toChain;
}
