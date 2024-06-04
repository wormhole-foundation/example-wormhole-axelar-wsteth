// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ITransceiver} from "@wormhole-foundation/native_token_transfer/interfaces/ITransceiver.sol";

interface IAxelarTransceiver is ITransceiver {
    error InvalidChainId(uint16 chainId);

    event SendTransceiverMessage(
        uint16 indexed recipientChainId,
        bytes nttManagerMessage,
        bytes32 indexed recipientNttManagerAddress,
        bytes32 indexed refundAddress
    );
}
