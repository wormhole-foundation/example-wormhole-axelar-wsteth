// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title IManaged Interface
 * @notice IManaged is an interface that abstracts the implementation of a
 * contract with managership control features. It's commonly used in upgradable
 * contracts and includes the functionality to get current manager, transfer
 * managership, and propose and accept managership.
 */
interface IManaged {
    error NotManager();
    error InvalidManager();
    error InvalidManagerAddress();

    event ManagerTransferStarted(address indexed newManager);
    event ManagerTransferred(address indexed newManager);

    /**
     * @notice Returns the current manager of the contract.
     * @return address The address of the current manager
     */
    function manager() external view returns (address);
}
