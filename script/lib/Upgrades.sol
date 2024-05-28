// SPDX-License-Identifier: Apache 2
// slither-disable-start reentrancy-benign
pragma solidity >=0.8.8 <0.9.0;

import {Vm} from "forge-std/Vm.sol";
import {Upgrades as OzUpgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {DefenderDeploy} from "@openzeppelin/foundry-upgrades/internal/DefenderDeploy.sol";

// Much of the code in this file was reused from https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades/blob/c50a7968d369f852607cb72e653d1ed699d823c5/src/Upgrades.sol.
library Upgrades {
    address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

    function deployUUPSProxy(
        string memory proxyContractPath,
        string memory contractName,
        bytes memory initializerData
    ) internal returns (address) {
        Options memory opts;
        address impl = OzUpgrades.deployImplementation(contractName, opts);
        return address(_deploy(proxyContractPath, abi.encode(impl, initializerData), opts));
    }

    function _deploy(
        string memory contractName,
        bytes memory constructorData,
        Options memory opts
    ) private returns (address) {
        if (opts.defender.useDefenderDeploy) {
            return DefenderDeploy.deploy(contractName, constructorData, opts.defender);
        } else {
            bytes memory creationCode = Vm(CHEATCODE_ADDRESS).getCode(contractName);
            address deployedAddress =
                _deployFromBytecode(abi.encodePacked(creationCode, constructorData));
            if (deployedAddress == address(0)) {
                revert(
                    string.concat(
                        "Failed to deploy contract ",
                        contractName,
                        ' using constructor data "',
                        string(constructorData),
                        '"'
                    )
                );
            }
            return deployedAddress;
        }
    }

    function _deployFromBytecode(bytes memory bytecode) private returns (address) {
        address addr;
        assembly {
            addr := create(0, add(bytecode, 32), mload(bytecode))
        }
        return addr;
    }
}