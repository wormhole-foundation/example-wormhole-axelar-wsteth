// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import {console2} from "forge-std/Script.sol";
import {IAxelarTransceiver} from "../src/axelar/interfaces/IAxelarTransceiver.sol";
import {ParseNttConfig} from
    "@wormhole-foundation/native_token_transfer/../script/helpers/ParseNttConfig.sol";

contract DeployAxelarTransceiver is ParseNttConfig {
    struct SetAxelarChainIdParams {
        IAxelarTransceiver axelarTransceiver;
        uint16 chainId;
        string axelarChainId;
        string transceiverAddress;
    }

    function run() public {
        SetAxelarChainIdParams memory params = _readEnvVariables();
        // Deploy the Wormhole Transceiver.

        params.axelarTransceiver.setAxelarChainId(
            params.chainId, params.axelarChainId, params.transceiverAddress
        );

        console2.log("Axelar Transceiver Address Updated");
        console2.log("ChainId: %s", params.chainId);
        console2.log("Axelar Chain Name: %s", params.axelarChainId);
        console2.log("Transceiver Address: %s", params.chainId);
    }

    function _readEnvVariables() internal view returns (SetAxelarChainIdParams memory params) {
        // Axelar Gateway.
        params.axelarTransceiver = IAxelarTransceiver(vm.envAddress("AXELAR_TRANSCEIVER"));
        require(
            address(params.axelarTransceiver) != address(0), "Invalid axelar transceiver address"
        );

        // Chain Id.
        params.chainId = uint16(vm.envUint("CHAIN_ID"));

        // Axelar Chain Id.
        params.axelarChainId = vm.envString("AXELAR_CHAIN_ID");
        require(bytes(params.axelarChainId).length != 0, "Empty axelar chain id");

        // Remote Transceiver Address.
        params.transceiverAddress = vm.envString("TRANSCEIVER_ADDRESS");
        require(bytes(params.transceiverAddress).length != 0, "Empty transceiver address");
    }
}
