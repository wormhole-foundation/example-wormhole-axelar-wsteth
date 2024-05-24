// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import {WstEthL2Token} from "src/token/WstEthL2Token.sol";

contract WstEthL2TokenHarness is WstEthL2Token {
    function exposed_authorizeUpgrade(address _newImplementation) external view {
        _authorizeUpgrade(_newImplementation);
    }
}