// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "../../src/axelar/AxelarTransceiver.sol";
import "./mock/MockGateway.sol";

import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/gas-service/AxelarGasService.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract GovernedContract is Ownable {
    error RandomError();

    bool public governanceStuffCalled;

    function governanceStuff() public onlyOwner {
        governanceStuffCalled = true;
    }

    function governanceRevert() public view onlyOwner {
        revert RandomError();
    }
}

contract AxelarTransceiverTest is Test {
    uint256 constant DEVNET_GUARDIAN_PK =
        0xcfb12303a19cde580bb4dd771639b0d26bc68353645571a8cff516ab2ee113a0;

    AxelarTransceiver trasnceiver;
    IAxelarGateway gateway;
    IAxelarGasService gasService;

    function setUp() public {
        string memory url = "https://ethereum-sepolia-rpc.publicnode.com";
        vm.createSelectFork(url);

        gateway = IAxelarGateway(new MockGateway());
        gateway = IAxelarGateway(new MockGateway());
        AxelarTransceiver implementation = new AxelarTransceiver(address(wormhole), DEVNET_GUARDIAN_PK);
        governance = new Governance(address(wormhole));

        myContract = new GovernedContract();
        myContract.transferOwnership(address(governance));
    }

    function test_parseGuardian() public {
        
    }

    
}