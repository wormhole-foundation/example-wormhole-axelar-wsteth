


// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "wormhole-solidity-sdk/Utils.sol";

import { TransceiverStructs } from "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";
import { INttManager } from "@wormhole-foundation/native_token_transfer/interfaces/INttManager.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {
    StringToAddress, AddressToString
} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import { Upgradable } from "@axelar-network/axelar-gmp-sdk-solidity/contracts/upgradable/Upgradable.sol";

import { IAxelarTransceiver } from './interfaces/IAxelarTransceiver.sol';

contract AxelarTransceiverProxy is ERC1967Proxy {
    constructor(address implementationAddress) ERC1967Proxy(implementationAddress, bytes("")) {}
}