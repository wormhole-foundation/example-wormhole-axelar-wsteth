// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IManaged } from '../interfaces/IManaged.sol';

/**
 * @title Managed
 * @notice A contract module which provides a basic access control mechanism, where
 * there is an account (an manager) that can be granted exclusive access to
 * specific functions.
 *
 * The manager account is set through managership transfer. This module makes
 * it possible to transfer the managership of the contract to a new account in one
 * step, as well as to an interim pending manager. In the second flow the managership does not
 * change until the pending manager accepts the managership transfer.
 */
abstract contract Managed is IManaged {
    address public immutable manager;

    /**
     * @notice Initializes the contract by transferring managership to the manager parameter.
     * @param _manager Address to set as the initial manager of the contract
     */
    constructor(address _manager) {
        manager = _manager;
    }

    /**
     * @notice Modifier that throws an error if called by any account other than the manager.
     */
    modifier onlyManager() {
        if (manager != msg.sender) revert NotManager();

        _;
    }
}
