// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { MockV3Aggregator } from "../src/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    uint8 private constant ETH_DECIMALS = 8;
    uint8 private constant BTC_DECIMALS = 8;
    int256 private constant LOCAL_ETH_USD_PRICE = 2_000e8;
    int256 private constant LOCAL_BTC_USD_PRICE = 30_000e8;

    uint256 private constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 private constant MAINNET_CHAIN_ID = 1;
    uint256 private constant LOCAL_CHAIN_ID = 31_337;

    error HelperConfig__InvalidPriceFeedAddress(address feed);

    // Chainlink ETH/USD and BTC/USD aggregator addresses by network.
    address private constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address private constant SEPOLIA_BTC_USD_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address private constant MAINNET_ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address private constant MAINNET_BTC_USD_FEED = 0x0f4030086522a5BEea4988F8cA5b36DBC97bee88;

    struct NetworkConfig {
        address ethUsdPriceFeed;
        address btcUsdPriceFeed;
    }

    NetworkConfig private activeNetworkConfig;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == MAINNET_CHAIN_ID) {
            activeNetworkConfig = getMainnetEthConfig();
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else {
            revert("HelperConfig: unsupported chain");
        }
        _validateNetworkConfig(activeNetworkConfig);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({ ethUsdPriceFeed: SEPOLIA_ETH_USD_FEED, btcUsdPriceFeed: SEPOLIA_BTC_USD_FEED });
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({ ethUsdPriceFeed: MAINNET_ETH_USD_FEED, btcUsdPriceFeed: MAINNET_BTC_USD_FEED });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.ethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        address ethUsdPriceFeed = address(new MockV3Aggregator(ETH_DECIMALS, LOCAL_ETH_USD_PRICE));
        address btcUsdPriceFeed = address(new MockV3Aggregator(BTC_DECIMALS, LOCAL_BTC_USD_PRICE));

        activeNetworkConfig = NetworkConfig({ ethUsdPriceFeed: ethUsdPriceFeed, btcUsdPriceFeed: btcUsdPriceFeed });
        return activeNetworkConfig;
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function _validateNetworkConfig(NetworkConfig memory config) private pure {
        if (config.ethUsdPriceFeed == address(0)) {
            revert HelperConfig__InvalidPriceFeedAddress(config.ethUsdPriceFeed);
        }
        if (config.btcUsdPriceFeed == address(0)) {
            revert HelperConfig__InvalidPriceFeedAddress(config.btcUsdPriceFeed);
        }
    }
}
