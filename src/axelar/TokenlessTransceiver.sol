// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "wormhole-solidity-sdk/Utils.sol";

import "@wormhole-foundation/native_token_transfer/libraries/TransceiverStructs.sol";
import "@wormhole-foundation/native_token_transfer/libraries/PausableOwnable.sol";
import "@wormhole-foundation/native_token_transfer/libraries/external/ReentrancyGuardUpgradeable.sol";
import "@wormhole-foundation/native_token_transfer/libraries/Implementation.sol";

import "@wormhole-foundation/native_token_transfer/interfaces/INttManager.sol";
import "@wormhole-foundation/native_token_transfer/interfaces/ITransceiver.sol";
import "@wormhole-foundation/native_token_transfer/interfaces/IOwnableUpgradeable.sol";

/// @title TokenlessTransceiver
/// @notice Base contract for transceivers that work with managers that don't have tokens
/// @dev Similar to Transceiver but handles managers that don't implement token()
abstract contract TokenlessTransceiver is
    ITransceiver,
    PausableOwnable,
    ReentrancyGuardUpgradeable,
    Implementation
{
    address public immutable nttManager;
    address immutable deployer;

    constructor(address _nttManager) {
        nttManager = _nttManager;
        deployer = msg.sender;
    }

    /// =============== MODIFIERS ===============================================

    modifier onlyNttManager() {
        if (msg.sender != nttManager) {
            revert CallerNotNttManager(msg.sender);
        }
        _;
    }

    /// =============== ADMIN ===============================================

    function _initialize() internal virtual override {
        // check if the owner is the deployer of this contract
        if (msg.sender != deployer) {
            revert UnexpectedDeployer(deployer, msg.sender);
        }

        __ReentrancyGuard_init();
        // owner of the transceiver is set to the owner of the nttManager
        __PausedOwnable_init(msg.sender, getNttManagerOwner());
    }

    /// @dev transfer the ownership of the transceiver to a new address
    /// the nttManager should be able to update transceiver ownership.
    function transferTransceiverOwnership(address newOwner) external onlyNttManager {
        _transferOwnership(newOwner);
    }

    function upgrade(address newImplementation) external onlyOwner {
        _upgrade(newImplementation);
    }

    function _migrate() internal virtual override {}

    // @define This method checks that the the referecnes to the nttManager and its corresponding function
    // are correct When new immutable variables are added, this function should be updated.
    function _checkImmutables() internal view virtual override {
        assert(this.nttManager() == nttManager);
    }

    /// =============== GETTERS & SETTERS ===============================================

    function getNttManagerOwner() public view returns (address) {
        return IOwnableUpgradeable(nttManager).owner();
    }

    function getNttManagerToken() public view virtual returns (address) {
        return address(0); // Tokenless manager doesn't have a token
    }

    function getTransceiverType() external view virtual returns (string memory);

    /// =============== TRANSCEIVING LOGIC ===============================================

    /// @inheritdoc ITransceiver
    function quoteDeliveryPrice(
        uint16 targetChain,
        TransceiverStructs.TransceiverInstruction memory instruction
    ) external view returns (uint256) {
        return _quoteDeliveryPrice(targetChain, instruction);
    }

    /// @inheritdoc ITransceiver
    function sendMessage(
        uint16 recipientChain,
        TransceiverStructs.TransceiverInstruction memory instruction,
        bytes memory nttManagerMessage,
        bytes32 recipientNttManagerAddress,
        bytes32 refundAddress
    ) external payable nonReentrant onlyNttManager {
        _sendMessage(
            recipientChain,
            msg.value,
            msg.sender,
            recipientNttManagerAddress,
            refundAddress,
            instruction,
            nttManagerMessage
        );
    }

    /// ============================= INTERNAL =========================================

    function _sendMessage(
        uint16 recipientChain,
        uint256 deliveryPayment,
        address caller,
        bytes32 recipientNttManagerAddress,
        bytes32 refundAddress,
        TransceiverStructs.TransceiverInstruction memory transceiverInstruction,
        bytes memory nttManagerMessage
    ) internal virtual;

    // @define This method is called by the BridgeNttManager contract to send a cross-chain message.
    // @reverts if:
    //     - `recipientNttManagerAddress` does not match the address of this manager contract
    function _deliverToNttManager(
        uint16 sourceChainId,
        bytes32 sourceNttManagerAddress,
        bytes32 recipientNttManagerAddress,
        TransceiverStructs.NttManagerMessage memory payload
    ) internal virtual {
        if (recipientNttManagerAddress != toWormholeFormat(nttManager)) {
            revert UnexpectedRecipientNttManagerAddress(
                toWormholeFormat(nttManager), recipientNttManagerAddress
            );
        }
        INttManager(nttManager).attestationReceived(sourceChainId, sourceNttManagerAddress, payload);
    }

    function _quoteDeliveryPrice(
        uint16 targetChain,
        TransceiverStructs.TransceiverInstruction memory transceiverInstruction
    ) internal view virtual returns (uint256);
}