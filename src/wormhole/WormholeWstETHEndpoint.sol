// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

import {EndpointStandalone} from "@wormhole-foundation/native_token_transfer/EndpointStandalone.sol";
import {WormholeEndpoint} from "@wormhole-foundation/native_token_transfer/WormholeEndpoint.sol";

contract WormholeWstETHEndpoint is WormholeEndpoint, EndpointStandalone {
    constructor(address manager, address wormholeCoreBridge, address wormholeRelayerAddr, address owner)
        EndpointStandalone(manager)
        WormholeEndpoint(wormholeCoreBridge, wormholeRelayerAddr)
    {}
}
