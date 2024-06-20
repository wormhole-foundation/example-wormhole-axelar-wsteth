// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Upgrades as OzUpgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Upgrades} from "script/lib/Upgrades.sol";
import {DefenderOptions} from "@openzeppelin/foundry-upgrades/Options.sol";
import {WstEthL2Token} from "src/token/WstEthL2Token.sol";
import {WstEthL2TokenHarness} from "test/token/WstEthL2TokenHarness.sol";
import {WstEthL2TokenV2Fake} from "test/token/WstEthL2TokenV2Fake.sol";
import {OwnableUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {INttToken} from "@wormhole-foundation/native_token_transfer/interfaces/INttToken.sol";

contract WstEthL2TokenTest is Test {
    WstEthL2TokenHarness token;
    address minter = makeAddr("NTT");
    address governance = makeAddr("Governance");
    uint256 MAX_INT = 2 ** 256 - 1;

    function setUp() public virtual {
        address proxy = Upgrades.deployUUPSProxy(
            "out/ERC1967Proxy.sol/ERC1967Proxy.json",
            "WstEthL2TokenHarness.sol",
            abi.encodeCall(WstEthL2Token.initialize, ("Wrapped Staked Eth", "wstEth", governance))
        );
        vm.label(proxy, "Proxy");

        token = WstEthL2TokenHarness(proxy);
        vm.prank(governance);
        token.setMinter(minter);
        vm.label(address(token), "WstEthL2Token");
    }

    // This internal method supplies options to `Upgrades.upgradeProxy`. For more information, see documentation in Options.sol
    function _upgradeProxyOpts() public returns (Options memory) {
        return Options({
            unsafeSkipAllChecks: vm.envOr("SKIP_SAFETY_CHECK_IN_UPGRADE_TEST", false),
            referenceContract: "",
            constructorData: "",
            unsafeAllow: "",
            unsafeAllowRenames: false,
            unsafeSkipStorageCheck: false,
            defender: DefenderOptions(false, false, "", bytes32(""), "")
        });
    }

    // Initialization and Upgrade tests

    function testFuzz_CorrectlyInitializesTheToken(
        string memory _name,
        string memory _symbol
    ) public {
        address proxy = Upgrades.deployUUPSProxy(
            "out/ERC1967Proxy.sol/ERC1967Proxy.json",
            "WstEthL2TokenHarness.sol",
            abi.encodeCall(WstEthL2Token.initialize, (_name, _symbol, governance))
        );
        vm.label(proxy, "Proxy");

        token = WstEthL2TokenHarness(proxy);
        vm.label(address(token), "WstEthL2Token");

        assertEq(token.symbol(), _symbol);
        assertEq(token.name(), _name);

        // Current balance is 0
        assertEq(token.totalSupply(), 0);

        // Check Roles are set up correctly
        assertEq(token.owner(), governance);
        assertEq(token.minter(), address(0));
    }

    function testFuzz_InitializedTokenOwnerCanSetAndChangeMinter(
        address _newMinter,
        uint256 _amount
    ) public {
        _amount = bound(_amount, 1, MAX_INT);
        vm.assume(_newMinter != address(0));

        // Grant new minter role
        vm.prank(governance);
        token.setMinter(_newMinter);

        // Verify new minter can do its duties
        vm.prank(_newMinter);
        token.mint(_newMinter, _amount);
        assertEq(token.minter(), _newMinter);
        assertEq(token.balanceOf(_newMinter), _amount);
        vm.prank(_newMinter);
        token.burn(_amount);
        assertEq(token.minter(), _newMinter);
        assertEq(token.balanceOf(_newMinter), 0);
    }

    // Switch owners
    function testFuzz_InitializedTokenCanSwitchOwner(address _newOwner) public {
        vm.assume(_newOwner != address(0));
        // Begin default admin transfer
        vm.prank(governance);
        token.transferOwnership(_newOwner);
        assertEq(token.owner(), _newOwner);
    }

    // Revert if initialized twice
    function testFuzz_RevertIf_TheInitializerIsCalledTwice(
        string memory _name,
        string memory _symbol,
        address _owner
    ) public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize(_name, _symbol, _owner);
    }

    // We limit the fuzz runs of this test because it performs FFI actions to run the node script, which takes
    // significant time and resources
    /// forge-config: default.fuzz.runs = 3
    function testFuzz_PerformsAndInitializesAnUpgradeThatAddsNewFunctionalityToTheToken(
        uint256 _initialValue,
        address _minter,
        uint256 _mintAmount,
        uint256 _burnAmount,
        uint256 _nextValue
    ) public {
        vm.assume(_minter != address(0));
        _mintAmount = bound(_mintAmount, 0, MAX_INT);
        _burnAmount = bound(_burnAmount, 0, _mintAmount);
        vm.assume(_mintAmount > _burnAmount);

        // Assign the minter role before performing the upgrade
        vm.prank(governance);
        token.setMinter(_minter);
        assertEq(token.minter(), _minter);

        // Perform the upgrade
        vm.startPrank(governance);
        OzUpgrades.upgradeProxy(
            address(token),
            "WstEthL2TokenV2Fake.sol",
            abi.encodeCall(WstEthL2TokenV2Fake.initializeFakeV2, (_initialValue)),
            _upgradeProxyOpts()
        );
        vm.stopPrank();

        // Ensure the contract is initialized correctly
        WstEthL2TokenV2Fake _tokenV2 = WstEthL2TokenV2Fake(address(token));
        assertEq(_tokenV2.fakeStateVar(), _initialValue);

        // Ensure we can exercise pre-upgrade functionality, such as minting
        // Ensure the storage applied pre-upgrade, in this case the minter, still functions as expected
        vm.prank(_minter);
        _tokenV2.mint(_minter, _mintAmount);
        assertEq(_tokenV2.balanceOf(_minter), _mintAmount);

        // Ensure we can exercise some new functionality included in the upgrade
        vm.prank(_minter);
        vm.expectEmit();
        emit WstEthL2TokenV2Fake.FakeStateVarSet(_initialValue, _nextValue);
        _tokenV2.setFakeStateVar(_nextValue);
        assertEq(_tokenV2.fakeStateVar(), _nextValue);

        // Ensure the role ACL applied to the new method works
        address _notMinter = address(uint160(uint256(keccak256(abi.encode(_minter)))));
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, _notMinter));
        vm.prank(_notMinter);
        token.mint(_notMinter, _mintAmount);

        // Ensure initialization cannot be called again
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _tokenV2.initialize("Wrapped Staked Eth", "wstEth", governance);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _tokenV2.initializeFakeV2(_nextValue);
    }

    function testFuzz_AuthorizeUpgradeForOwner(address _newImplementation) public {
        vm.prank(governance);
        token.exposed_authorizeUpgrade(_newImplementation);
    }

    function testFuzz_RevertIf_NotCalledByOwner(
        address _caller,
        address _newImplementation
    ) public {
        vm.assume(_caller != governance);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _caller)
        );
        vm.prank(_caller);
        token.exposed_authorizeUpgrade(_newImplementation);
    }

    // Mint/burn tests

    function testFuzz_RevertIf_MintNonMinter(address _caller, uint256 _amount) public {
        vm.assume(_caller != minter);

        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, _caller));
        vm.prank(_caller);
        token.mint(_caller, _amount);
    }

    function testFuzz_RevertIf_NonOwner(address _caller) public {
        vm.assume(_caller != governance);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _caller)
        );
        vm.prank(_caller);
        token.setMinter(_caller);
    }

    function testFuzz_CorrectlyMintTokensForANewAddress(address _account, uint256 _amount) public {
        _amount = bound(_amount, 0, MAX_INT);
        vm.assume(_account != address(0));
        vm.prank(minter);
        token.mint(_account, _amount);

        assertEq(token.balanceOf(_account), _amount);
    }

    function testFuzz_CorrectlyBurnTokensForANewAddress(
        uint256 _mintAmount,
        uint256 _burnAmount
    ) public {
        _mintAmount = bound(_mintAmount, 0, MAX_INT);
        _burnAmount = bound(_burnAmount, 0, _mintAmount);

        vm.startPrank(minter);
        token.mint(minter, _mintAmount);
        token.burn(_burnAmount);
        vm.stopPrank();

        assertEq(token.totalSupply(), _mintAmount - _burnAmount);
    }

    function testFuzz_RevertIf_BurnCalledByNonMinterAddress(
        address _caller,
        uint256 _burnAmount
    ) public {
        vm.assume(_caller != minter);
        _burnAmount = bound(_burnAmount, 0, MAX_INT);

        vm.prank(minter);
        token.mint(minter, _burnAmount);

        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, _caller));
        vm.prank(_caller);
        token.burn(_burnAmount);
    }

    // BurnFrom test

    function testFuzz_RevertIf_Called(address _burnFrom, uint256 _amount) public {
        vm.expectRevert(WstEthL2Token.UnimplementedMethod.selector);
        token.burnFrom(_burnFrom, _amount);
    }
}
