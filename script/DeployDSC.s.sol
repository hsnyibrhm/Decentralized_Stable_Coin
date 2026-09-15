// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { DecentralizedStableCoin } from "../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../src/DSCEngine.sol";
import { MockERC20 } from "../src/mocks/MockERC20.sol";
import { MockV3Aggregator } from "../src/mocks/MockV3Aggregator.sol";

contract DeployDSC is Script {
    uint256 private constant LOCAL_CHAIN_ID = 31337;
    uint8 private constant FEED_DECIMALS = 8;
    int256 private constant ETH_USD_PRICE = 2000e8;

    function run() external returns (DSCEngine engine, DecentralizedStableCoin dsc) {
        vm.startBroadcast();

        address collateralToken;
        address priceFeed;
        if (block.chainid == LOCAL_CHAIN_ID) {
            collateralToken = address(new MockERC20());
            priceFeed = address(new MockV3Aggregator(FEED_DECIMALS, ETH_USD_PRICE));
        } else {
            collateralToken = vm.envAddress("COLLATERAL_TOKEN");
            priceFeed = vm.envAddress("COLLATERAL_PRICE_FEED");
        }

        dsc = new DecentralizedStableCoin();
        address[] memory collateralTokens = new address[](1);
        address[] memory priceFeeds = new address[](1);
        collateralTokens[0] = collateralToken;
        priceFeeds[0] = priceFeed;
        engine = new DSCEngine(collateralTokens, priceFeeds, address(dsc));
        dsc.transferOwnership(address(engine));

        vm.stopBroadcast();
    }
}
