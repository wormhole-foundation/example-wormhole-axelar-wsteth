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
    /// @param chainName The axelar chainName.
    /// @param transceiverAddress The address of the Transceiver as a string.
    error InvalidChainId(uint16 chainId, string chainName, string transceiverAddress);

    /// @notice Chain Id passed is zero.
    error ZeroChainId();

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

    /// @notice Emmited when the chain id is set.
    /// @param chainId The wormhole chainId of the destination chain.
    /// @param chainName The axelar chain name.
    /// @param transceiverAddress The transceiver address as a string.
    event AxelarChainIdSet(uint16 chainId, string chainName, string transceiverAddress);

    /**
     * Set the bridge manager contract address
     * @param chainId The chainId of the chain. This is used to identify the chain in the EndpointManager.
     * @param chainName The chainName of the chain. This is used to identify the chain in the AxelarGateway.
     * @param transceiverAddress The address of the tranceiver on the other chain, in the axelar accepted format.
     */
    function setAxelarChainId(
        uint16 chainId,
        string calldata chainName,
        string calldata transceiverAddress
    ) external;
}
