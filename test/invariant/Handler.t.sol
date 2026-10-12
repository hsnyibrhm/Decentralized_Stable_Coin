// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { ERC20Mock } from "../../lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../../src/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) external {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, type(uint96).max);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) external {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 collateralBalance = dscEngine.getCollateralBalanceOfUser(msg.sender, address(collateral));
        if (collateralBalance == 0) return;

        amountCollateral = bound(amountCollateral, 1, collateralBalance);

        vm.startPrank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function mintDsc(uint256 amountDsc) external {
        amountDsc = bound(amountDsc, 1, type(uint96).max);

        vm.startPrank(msg.sender);
        dscEngine.mintDsc(amountDsc);
        vm.stopPrank();
    }

    function updateCollateralPrice(uint96 newPrice) external {
        newPrice = uint96(bound(newPrice, 1, type(uint96).max));
        int256 newPriceInt = int256(uint256(newPrice));

        MockV3Aggregator wethPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
        MockV3Aggregator wbtcPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wbtc)));

        wethPriceFeed.updateAnswer(newPriceInt);
        wbtcPriceFeed.updateAnswer(newPriceInt);
    }
}
