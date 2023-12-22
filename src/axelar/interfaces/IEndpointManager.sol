// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IEndpointManager {
    /// @notice Called by the user to send wstETH cross-chain.
    ///         This function will either lock or burn the sender's tokens.
    ///         If locking - this function will use transferFrom to pull tokens from the user and lock them.
    ///         If burning - this function will call the token's burn function to burn the sender's token.
    ///         Finally, this function will call into the Endpoint contracts to send a message with the incrementing msgId sequence number, msgType = 1, and the token transfer payload.
    function transfer(
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipient
    ) external returns (uint64 msgId);

    /// @notice Called by a Endpoint contract to deliver a verified attestation.
    ///         This function will decode the payload as a BridgeManagerMessage to extract the msgId, msgType, and other parameters.
    ///         When the threshold is reached for a msgId, this function will execute logic to handle the action specified by the msgType and payload.
    function attestationReceived(bytes memory payload) external;

    /// @notice Returns the number of Endpoints that must attest to a msgId for it to be considered valid and acted upon.
    function getThreshold() external view returns (uint8);

    /// @notice Returns the Endpoint contracts that have been registered via governance.
    function getEndpoints() external view returns (address[] memory);
}
