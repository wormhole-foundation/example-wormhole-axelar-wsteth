


// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "wormhole-solidity-sdk/Utils.sol";

import { TransceiverStructs } from "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";
import { INttManager } from "@wormhole-foundation/native_token_transfer/interfaces/INttManager.sol";

import {Proxy} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/upgradable/Proxy.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {
    StringToAddress, AddressToString
} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import { Upgradable } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/upgradable/Upgradable.sol";

import {Managed} from "./utils/Managed.sol";
import { IAxelarTransceiver } from './interfaces/IAxelarTransceiver.sol';

contract AxelarTransceiverProxy is Proxy {
    constructor(address implementationAddress, address owner, bytes memory setupParams) Proxy(implementationAddress, owner, setupParams) {}

    function contractId() internal pure virtual override returns (bytes32) {
        return keccak256(bytes('axelar-transceiver'));
    }
}