// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import {console2} from "forge-std/Script.sol";
import {AxelarTransceiver} from "../src/axelar/AxelarTransceiver.sol";
import {TransceiverStructs} from
    "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";
import {NttManager} from "@wormhole-foundation/native_token_transfer/NttManager/NttManager.sol";
import {INttManager} from "@wormhole-foundation/native_token_transfer/interfaces/INttManager.sol";
import {IManagerBase} from "@wormhole-foundation/native_token_transfer/interfaces/IManagerBase.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ParseNttConfig} from
    "@wormhole-foundation/native_token_transfer/../script/helpers/ParseNttConfig.sol";

contract DeployAxelarTransceiver is ParseNttConfig {
    struct DeploymentParams {
        address axelarGatewayAddress;
        address axelarGasServiceAddress;
        address nttManagerAddress;
    }

    function run() public returns (address) {
        DeploymentParams memory params = _readEnvVariables();
        // Deploy the Wormhole Transceiver.
        AxelarTransceiver implementation = new AxelarTransceiver(
            params.axelarGatewayAddress, params.axelarGasServiceAddress, params.nttManagerAddress
        );

        AxelarTransceiver transceiverProxy =
            AxelarTransceiver(address(new ERC1967Proxy(address(implementation), "")));

        transceiverProxy.initialize();

        console2.log("Axelar Transceiver deployed at: ");
        console2.logBytes32(toUniversalAddress(address(transceiverProxy)));

        return address(transceiverProxy);
    }

    function _readEnvVariables() internal view returns (DeploymentParams memory params) {
        // Axelar Gateway.
        params.axelarGatewayAddress = vm.envAddress("AXELAR_GATEWAY");
        require(params.axelarGatewayAddress != address(0), "Invalid axelar gateway address");

        // Axelar Gateway.
        params.axelarGasServiceAddress = vm.envAddress("AXELAR_GAS_SERVICE");
        require(params.axelarGasServiceAddress != address(0), "Invalid axelar gas service address");

        // Axelar Gateway.
        params.nttManagerAddress = vm.envAddress("NTT_MANAGER");
        require(params.nttManagerAddress != address(0), "Invalid ntt manager address address");
    }
}
