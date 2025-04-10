require('dotenv').config();
require('@nomicfoundation/hardhat-toolbox');
require('solidity-coverage');
require('solidity-docgen');
require('hardhat-contract-sizer');
require('@nomicfoundation/hardhat-foundry')

const env = process.env.ENV || 'testnet';
const { importNetworks, readJSON } = require('@axelar-network/axelar-chains-config');
const chains = require(`@axelar-network/axelar-chains-config/info/${env}.json`);
const keys = readJSON(`${__dirname}/keys.json`);
const { networks, etherscan } = importNetworks(chains, keys);

const optimizerSettings = {
    enabled: true,
    runs: 200,
    details: {
        peephole: process.env.COVERAGE === undefined,
        inliner: process.env.COVERAGE === undefined,
        jumpdestRemover: true,
        orderLiterals: true,
        deduplicate: true,
        cse: process.env.COVERAGE === undefined,
        constantOptimizer: true,
        yul: true,
        yulDetails: {
            stackAllocation: true,
        },
    },
};
const compilerSettings = {
    version: '0.8.23',
    settings: {
        evmVersion: process.env.EVM_VERSION || 'london',
        optimizer: optimizerSettings,
    },
};
const itsCompilerSettings = {
    version: '0.8.21',
    settings: {
        evmVersion: process.env.EVM_VERSION || 'london',
        optimizer: {
            ...optimizerSettings,
            runs: 600, // Reduce runs to keep bytecode size under limit
        },
    },
};

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: {
        compilers: [compilerSettings],
        // Fix the Proxy bytecodes
        overrides: process.env.NO_OVERRIDES
            ? {}
            : {
                  'contracts/proxies/Proxy.sol': compilerSettings,
                  'contracts/proxies/TokenManagerProxy.sol': compilerSettings,
                  'contracts/InterchainTokenService.sol': itsCompilerSettings,
                  'contracts/test/TestInterchainTokenService.sol': itsCompilerSettings,
              },
    },
    defaultNetwork: 'hardhat',
    networks: {
        binance: {
            name: 'Binance',
            id: 'binance',
            axelarId: 'binance',
            chainId: 97,
            rpc: 'https://bsc-testnet-rpc.publicnode.com',
            tokenSymbol: 'BNB',
            gasOptions: { gasPriceAdjustment: 1.4 },
            explorer: {
            name: 'Bscscan',
            url: 'https://testnet.bscscan.com',
            api: 'https://api-testnet.bscscan.com/api'
                },
            finality: 'finalized',
            approxFinalityWaitTime: 2,
            url: 'https://bsc-testnet-rpc.publicnode.com',
            blockGasLimit: undefined,
        },
    },
    etherscan: {
        apiKey: {
            binance: "PBKFBQESZ3DTWGATC8K51GCKN5B5IR9T47",
        },
    },
    mocha: {
        timeout: 1000000,
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        excludeContracts: ['contracts/test'],
    },
    paths: {
        sources: "./src",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
      },
    contractSizer: {
        runOnCompile: process.env.CHECK_CONTRACT_SIZE,
        strict: process.env.CHECK_CONTRACT_SIZE,
        except: ['contracts/test'],
    },
};
