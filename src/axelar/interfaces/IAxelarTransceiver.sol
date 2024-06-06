// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ITransceiver} from "@wormhole-foundation/native_token_transfer/interfaces/ITransceiver.sol";

interface IAxelarTransceiver is ITransceiver {
    /// @notice Chain is not supported.
    /// @param chainId The wormhole chainId.
    /// @param sourceChain The source chain axelar name.
    /// @param sourceAddress The source address as indexed by axelar.
    error InvalidSibling(uint16 chainId, string sourceChain, string sourceAddress);

    /// @notice Chain Id passed is not valid.
    /// @param chainId The wormhole chainId.
    error InvalidChainId(uint16 chainId);

    /// @notice Emmited when a transceiver message is sent.
    /// @param recipientChainId The wormhole chainId of the destination chain.
    /// @param nttManagerMessage The message sent.
    /// @param recipientNttManagerAddress The wormhole formatted address for the recepient NttManager.
    /// @param refundAddress The wormhole formatted address for the refund address.
    event SendTransceiverMessage(
        uint16 indexed recipientChainId,
        bytes nttManagerMessage,
        bytes32 indexed recipientNttManagerAddress,
        bytes32 indexed refundAddress
    );
}
