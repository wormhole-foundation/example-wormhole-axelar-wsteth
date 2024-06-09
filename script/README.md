## Deploying the Axelar Transceiver

First create a `.env` file in the root directory and add the following 3 parameters corresponding to the deployments on target chain.
- AXELAR_GATEWAY: The address of the Axelar gateway on this chain.
- AXELAR_GAS_SERVICE: The address of the Axelar Gas Service on this chain.
- NTT_MANAGER: The address of the NttManager on this chain.

Axelar contract addresses can be found [here](https://docs.axelar.dev/resources/contract-addresses/mainnet) (switch to mainnet/testnet appropriately). Chain name strings registered on Axelar can also be found there. For e.g. Ethereum is registered as `Ethereum` on mainnet, and `ethereum-sepolia` on testnet, and BSC smart chain is registered as `binance` on mainnet and testnet. These chain names should be used when setting the mapping between Wormhole chain ids and Axelar chain ids. For setting the Axelar transceiver addresses on different chains, [ERC-55](https://eips.ethereum.org/EIPS/eip-55) case sensitive representation should be used (shown by default on explorers).

Then run `forge script --chain {chain_name} DeployAxelarTransceiver.sol` to deploy the Axelar Transceiver.

## Setting Remote Chain Information

Add to the `.env` file in the root directory the following variables:
- AXELAR_TRANSCEIVER: The address of the axelar tranceiver on the current chain
- CHAIN_ID: The chain id of the remote chain
- AXELAR_CHAIN_ID: The name of the remote chain that Axelar understands.
- TRANSCEIVER_ADDRESS: The address of the remote transceiver that Axelar understands (0x prefixed string representation).