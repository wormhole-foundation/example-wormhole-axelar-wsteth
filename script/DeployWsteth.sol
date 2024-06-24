// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.7 <0.9.0;

import {Script, console} from "forge-std/Script.sol";
import {WstEthL2Token} from "../src/token/WstEthL2Token.sol";
import {Upgrades} from "./lib/Upgrades.sol";

contract DeployToken is Script {
    function run() public {
        vm.startBroadcast();

        address proxy = Upgrades.deployUUPSProxy(
            "out/ERC1967Proxy.sol/ERC1967Proxy.json",
            "WstEthL2Token.sol",
            abi.encodeCall(WstEthL2Token.initialize, ("Wrapped liquid staked Ether 2.0", "wstETH", msg.sender))
        );

        WstEthL2Token token = WstEthL2Token(proxy);

        console.log("WstEthL2Token deployed at: ");
        console.log(address(token));
        vm.stopBroadcast();
    }

    function transferOwnership(address tokenAddress, address newOwner, address minter) public {
        vm.startBroadcast();

        WstEthL2Token token = WstEthL2Token(tokenAddress);
        token.setMinter(minter);
        token.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}