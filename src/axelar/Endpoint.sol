// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import {IEndpoint} from "./interfaces/IEndpoint.sol";

abstract contract Endpoint is IEndpoint {
    /// updating bridgeManager requires a new Endpoint deployment.
    /// The LDO governance process is used to remove the old Endpoint contract address and then add the new one.
    address manager;
    // Mapping of emitters on other chains
    mapping(uint16 => bytes32) emitters;
    // TODO -- Add state to prevent messages from being double-submitted. Could be VAA hash and Axelar equivalent? Or could hash the entire EndpointMessage (but need unique fields like blocknum and timestamp then).

    modifier onlyManager() {
        require(msg.sender == manager, "Caller is not the Manager");
        _;
    }

    /// @notice Called by the BridgeManager contract to send a cross-chain message.
    function sendMessage(
        uint16 recipientChain,
        bytes memory payload
    ) external payable override onlyManager {
        _sendMessage(recipientChain, payload);
    }

    function _sendMessage(
        uint16 recipientChain,
        bytes memory payload
    ) internal virtual;

    /// @notice Receive an attested message from the verification layer
    ///         This function should verify the encodedVm and then call attestationReceived on the bridge manager contract.
    function receiveMessage(bytes memory encodedMessage) external virtual;

    /// @notice Get the corresponding Endpoint contract on other chains that have been registered via governance.
    ///         This design should be extendable to other chains, so each Endpoint would be potentially concerned with Endpoints on multiple other chains
    ///         Note that emitters are registered under wormhole chainID values
    function getEmitter(
        uint16 chainId
    ) external view override returns (bytes32) {
        return emitters[chainId];
    }

    function setEmitter(
        uint16 chainId,
        bytes32 bridgeContract
    ) internal onlyManager {
        emitters[chainId] = bridgeContract;
    }
}
