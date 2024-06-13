// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.19;

interface INTTToken {
    error CallerNotMinter(address caller);

    function mint(address account, uint256 amount) external;
}
