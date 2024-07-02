// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.7 <0.9.0;

import {Script, console} from "forge-std/Script.sol";
import {WstEthL2Token} from "../src/token/WstEthL2Token.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployToken is Script {
    function run() public returns (address implementation, address token) {
        vm.startBroadcast();

        implementation = address(new WstEthL2Token());

        token = address(new ERC1967Proxy(implementation, abi.encodeCall(WstEthL2Token.initialize, ("Wrapped liquid staked Ether 2.0", "wstETH", msg.sender))));

        console.log("WstEthL2Token implementation deployed at: ");
        console.log(implementation);

        console.log("WstEthL2Token proxy deployed at: ");
        console.log(token);
        vm.stopBroadcast();
    }

    function transferMinterAndOwnership(address tokenAddress, address newOwner, address minter) public {
        vm.startBroadcast();

        WstEthL2Token token = WstEthL2Token(tokenAddress);
        token.setMinter(minter);
        token.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}