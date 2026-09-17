// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { DSCEngine } from "../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../src/DecentralizedStableCoin.sol";
import { MockERC20 } from "../src/mocks/MockERC20.sol";
import { MockV3Aggregator } from "../src/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    uint256 private constant COLLATERAL_AMOUNT = 10 ether;
    uint256 private constant DSC_AMOUNT = 1000 ether;
    uint256 private constant LIQUIDATION_DSC_AMOUNT = 10_000 ether;
    uint8 private constant FEED_DECIMALS = 8;
    int256 private constant ETH_USD_PRICE = 2000e8;

    DSCEngine private engine;
    DecentralizedStableCoin private dsc;
    MockERC20 private collateral;
    MockV3Aggregator private priceFeed;
    address private user = makeAddr("user");
    address private liquidator = makeAddr("liquidator");

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(user);
        engine.depositCollateral(address(collateral), COLLATERAL_AMOUNT);
        engine.mintDsc(LIQUIDATION_DSC_AMOUNT);
        vm.stopPrank();
        _;
    }

    modifier liquidatorHasDsc() {
        vm.prank(user);
        dsc.transfer(liquidator, DSC_AMOUNT);
        vm.prank(liquidator);
        dsc.approve(address(engine), type(uint256).max);
        _;
    }

    function setUp() public {
        collateral = new MockERC20();
        priceFeed = new MockV3Aggregator(FEED_DECIMALS, ETH_USD_PRICE);
        dsc = new DecentralizedStableCoin();

        address[] memory collateralTokens = new address[](1);
        address[] memory priceFeeds = new address[](1);
        collateralTokens[0] = address(collateral);
        priceFeeds[0] = address(priceFeed);
        engine = new DSCEngine(collateralTokens, priceFeeds, address(dsc));
        dsc.transferOwnership(address(engine));

        collateral.mint(user, COLLATERAL_AMOUNT);
        vm.startPrank(user);
        collateral.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function testMintDscAgainstCollateral() public {
        vm.startPrank(user);
        engine.depositCollateral(address(collateral), COLLATERAL_AMOUNT);
        engine.mintDsc(DSC_AMOUNT);
        vm.stopPrank();

        assertEq(dsc.balanceOf(user), DSC_AMOUNT);
        assertEq(engine.getDscMinted(user), DSC_AMOUNT);
        vm.prank(user);
        assertEq(engine.getHealthFactor(), 10e18);
    }

    function testDepositCollateralAndMintDsc() public {
        vm.prank(user);
        engine.depositCollateralAndMintDsc(address(collateral), COLLATERAL_AMOUNT, DSC_AMOUNT);

        assertEq(collateral.balanceOf(address(engine)), COLLATERAL_AMOUNT);
        assertEq(engine.getCollateralBalanceOfUser(user, address(collateral)), COLLATERAL_AMOUNT);
        assertEq(dsc.balanceOf(user), DSC_AMOUNT);
        assertEq(engine.getDscMinted(user), DSC_AMOUNT);
    }

    function testRevertIfMintBreaksHealthFactor() public {
        vm.startPrank(user);
        engine.depositCollateral(address(collateral), COLLATERAL_AMOUNT);
        vm.expectRevert();
        engine.mintDsc(10_001 ether);
        vm.stopPrank();

        assertEq(dsc.balanceOf(user), 0);
        assertEq(engine.getDscMinted(user), 0);
    }

    function testRevertIfMintAmountIsZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.mintDsc(0);
    }

    function testOnlyEngineCanMintDsc() public {
        assertEq(dsc.owner(), address(engine));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        dsc.mint(user, DSC_AMOUNT);
    }

    function testLiquidation() public depositedCollateralAndMintedDsc liquidatorHasDsc {
        priceFeed.updateAnswer(1800e8);
        uint256 debtToCover = 1000 ether;
        uint256 expectedCollateralRedeemed = engine.getTokenAmountFromUsd(address(collateral), debtToCover);
        expectedCollateralRedeemed = expectedCollateralRedeemed + (expectedCollateralRedeemed * 10) / 100;

        vm.prank(liquidator);
        engine.liquidate(address(collateral), user, debtToCover);

        assertEq(engine.getDscMinted(user), LIQUIDATION_DSC_AMOUNT - debtToCover);
        assertEq(
            engine.getCollateralBalanceOfUser(user, address(collateral)), COLLATERAL_AMOUNT - expectedCollateralRedeemed
        );
        assertEq(collateral.balanceOf(liquidator), expectedCollateralRedeemed);
        assertEq(dsc.balanceOf(liquidator), DSC_AMOUNT - debtToCover);
    }
}
