// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import {WstEthL2Token} from "src/token/WstEthL2Token.sol";

/// @dev This is a "fake" version 2 of the WstEthL2Token, used only for testing that the upgrade functionality is
/// behaving as expected.
/// @custom:oz-upgrades-from WstEthL2Token
contract WstEthL2TokenFake is WstEthL2Token {
    event FakeStateVarSet(uint256 oldValue, uint256 newValue);

    uint256 public fakeStateVar;

    function initializeFakeV2(uint256 _initialValue) public reinitializer(2) {
        fakeStateVar = _initialValue;
        emit FakeStateVarSet(0, _initialValue);
    }

    function setFakeStateVar(uint256 _newValue) public onlyMinter {
        emit FakeStateVarSet(fakeStateVar, _newValue);
        fakeStateVar = _newValue;
    }
}