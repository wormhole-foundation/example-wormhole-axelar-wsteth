// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "../interfaces/external/INTTToken.sol";

contract wstETHL2Token is INTTToken, ERC20Burnable, Ownable {
    address immutable _minter;

    modifier onlyMinter() {
        if (msg.sender != _minter) {
            revert CallerNotMinter(msg.sender);
        }
        _;
    }

    constructor(string memory name, string memory symbol, address minter, address owner)
        ERC20(name, symbol)
    {
        _minter = minter;
        _transferOwnership(owner);
    }

    function mint(address account, uint256 amount) external onlyMinter {
        _mint(account, amount);
    }
}
