// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { DSCEngine } from "../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../src/DecentralizedStableCoin.sol";
import { MockERC20 } from "../src/mocks/MockERC20.sol";
import { MockV3Aggregator } from "../src/mocks/MockV3Aggregator.sol";
import { MockFailedTransferFrom } from "../src/mocks/MockFailedTransferFrom.sol";
import { MockFailedTransfer } from "../src/mocks/MockFailedTransfer.sol";
import { MockFailedMintDSC } from "../src/mocks/MockFailedMintDSC.sol";

contract DSCEngineTest is Test {
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

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

    modifier depositedCollateral() {
        vm.startPrank(user);
        engine.depositCollateral(address(collateral), COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

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

    function testGetTokenAmountFromUsd() public view {
        assertEq(engine.getTokenAmountFromUsd(address(collateral), 100 ether), 0.05 ether);
    }

    function testGetUsdValue() public view {
        assertEq(engine.getUsdValue(address(collateral), 15 ether), 30_000 ether);
    }

    function testRevertsIfCollateralAmountIsZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.depositCollateral(address(collateral), 0);
    }

    function testRevertsWithUnapprovedCollateral() public {
        MockERC20 randomCollateral = new MockERC20();
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(randomCollateral), COLLATERAL_AMOUNT);
    }

    function testRevertsIfTransferFromFails() public {
        MockFailedTransferFrom failedCollateral = new MockFailedTransferFrom();
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](1);
        tokenAddresses[0] = address(failedCollateral);
        priceFeedAddresses[0] = address(priceFeed);
        DSCEngine failedEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        failedCollateral.mint(user, COLLATERAL_AMOUNT);

        vm.startPrank(user);
        failedCollateral.approve(address(failedEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        failedEngine.depositCollateral(address(failedCollateral), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testRevertsIfTransferFails() public {
        MockFailedTransfer failedCollateral = new MockFailedTransfer();
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](1);
        tokenAddresses[0] = address(failedCollateral);
        priceFeedAddresses[0] = address(priceFeed);
        DSCEngine failedEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        failedCollateral.mint(user, COLLATERAL_AMOUNT);

        vm.startPrank(user);
        failedCollateral.approve(address(failedEngine), COLLATERAL_AMOUNT);
        failedEngine.depositCollateral(address(failedCollateral), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        failedEngine.redeemCollateral(address(failedCollateral), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testRevertsIfMintFails() public {
        MockFailedMintDSC failedDsc = new MockFailedMintDSC();
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](1);
        tokenAddresses[0] = address(collateral);
        priceFeedAddresses[0] = address(priceFeed);
        DSCEngine failedEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedDsc));
        failedDsc.transferOwnership(address(failedEngine));

        vm.startPrank(user);
        collateral.approve(address(failedEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        failedEngine.depositCollateralAndMintDsc(address(collateral), COLLATERAL_AMOUNT, DSC_AMOUNT);
        vm.stopPrank();
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        assertEq(dsc.balanceOf(user), 0);
        assertEq(engine.getCollateralBalanceOfUser(user, address(collateral)), COLLATERAL_AMOUNT);
    }

    function testCanGetAccountInformation() public depositedCollateral {
        (uint256 dscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(user);
        assertEq(dscMinted, 0);
        assertEq(collateralValueInUsd, engine.getUsdValue(address(collateral), COLLATERAL_AMOUNT));
    }

    function testCannotMintWithoutCollateral() public {
        uint256 expectedHealthFactor = engine.calculateHealthFactor(DSC_AMOUNT, 0);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.mintDsc(DSC_AMOUNT);
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        dsc.approve(address(engine), LIQUIDATION_DSC_AMOUNT);
        engine.burnDsc(LIQUIDATION_DSC_AMOUNT);
        vm.stopPrank();

        assertEq(dsc.balanceOf(user), 0);
        assertEq(engine.getDscMinted(user), 0);
    }

    function testRevertsIfBurnAmountIsZero() public depositedCollateralAndMintedDsc {
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.burnDsc(0);
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.prank(user);
        engine.redeemCollateral(address(collateral), COLLATERAL_AMOUNT);

        assertEq(engine.getCollateralBalanceOfUser(user, address(collateral)), 0);
        assertEq(collateral.balanceOf(user), COLLATERAL_AMOUNT);
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.redeemCollateral(address(collateral), 0);
    }

    function testCanRedeemCollateralForDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        dsc.approve(address(engine), LIQUIDATION_DSC_AMOUNT);
        engine.redeemCollateralForDsc(address(collateral), COLLATERAL_AMOUNT, LIQUIDATION_DSC_AMOUNT);
        vm.stopPrank();

        assertEq(dsc.balanceOf(user), 0);
        assertEq(engine.getDscMinted(user), 0);
        assertEq(engine.getCollateralBalanceOfUser(user, address(collateral)), 0);
    }

    function testLiquidationRevertsForHealthyUser() public depositedCollateralAndMintedDsc liquidatorHasDsc {
        vm.prank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(address(collateral), user, DSC_AMOUNT);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedDsc {
        priceFeed.updateAnswer(180e8);

        assertEq(engine.getHealthFactor(user), 9e16);
    }

    function testLiquidationPayoutIncludesBonus() public depositedCollateralAndMintedDsc liquidatorHasDsc {
        priceFeed.updateAnswer(1800e8);
        uint256 debtToCover = 1000 ether;
        uint256 collateralForDebt = engine.getTokenAmountFromUsd(address(collateral), debtToCover);
        uint256 expectedCollateral =
            collateralForDebt + (collateralForDebt * engine.getLiquidationBonus()) / engine.getLiquidationPrecision();

        vm.prank(liquidator);
        engine.liquidate(address(collateral), user, debtToCover);

        assertEq(collateral.balanceOf(liquidator), expectedCollateral);
    }

    function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(engine));
        emit CollateralRedeemed(user, user, address(collateral), COLLATERAL_AMOUNT);

        vm.prank(user);
        engine.redeemCollateral(address(collateral), COLLATERAL_AMOUNT);
    }

    function testGetEngineConfiguration() public view {
        assertEq(engine.getDsc(), address(dsc));
        assertEq(engine.getDscAddress(), address(dsc));
        assertEq(engine.getCollateralTokenPriceFeed(address(collateral)), address(priceFeed));
        assertEq(engine.getCollateralTokens()[0], address(collateral));
        assertEq(engine.getPrecision(), 1e18);
        assertEq(engine.getAdditionalFeedPrecision(), 1e10);
        assertEq(engine.getLiquidationThreshold(), 50);
        assertEq(engine.getLiquidationBonus(), 10);
        assertEq(engine.getLiquidationPrecision(), 100);
        assertEq(engine.getMinHealthFactor(), 1e18);
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

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](0);
        tokenAddresses[0] = address(collateral);

        vm.expectRevert(DSCEngine.DSCEngine_TokenAddressAndPriceFeedAddressMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
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

    function testMintAtHealthFactorBoundaryAndRejectOneWeiAbove() public {
        vm.startPrank(user);
        engine.depositCollateral(address(collateral), COLLATERAL_AMOUNT);
        engine.mintDsc(10_000 ether);
        vm.stopPrank();

        assertEq(engine.getHealthFactor(user), engine.getMinHealthFactor());

        uint256 expectedHealthFactor = engine.calculateHealthFactor(10_000 ether + 1, 20_000 ether);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.mintDsc(1);

        assertEq(engine.getDscMinted(user), 10_000 ether);
        assertEq(dsc.balanceOf(user), 10_000 ether);
    }

    function testCollateralAndDebtAreIsolatedBetweenUsers() public {
        address secondUser = makeAddr("secondUser");
        uint256 secondUserCollateral = 2.5 ether;
        uint256 secondUserDebt = 500 ether;
        collateral.mint(secondUser, secondUserCollateral);

        vm.startPrank(user);
        engine.depositCollateral(address(collateral), COLLATERAL_AMOUNT);
        engine.mintDsc(DSC_AMOUNT);
        vm.stopPrank();

        vm.startPrank(secondUser);
        collateral.approve(address(engine), secondUserCollateral);
        engine.depositCollateral(address(collateral), secondUserCollateral);
        engine.mintDsc(secondUserDebt);
        vm.stopPrank();

        assertEq(engine.getCollateralBalanceOfUser(user, address(collateral)), COLLATERAL_AMOUNT);
        assertEq(engine.getCollateralBalanceOfUser(secondUser, address(collateral)), secondUserCollateral);
        assertEq(engine.getDscMinted(user), DSC_AMOUNT);
        assertEq(engine.getDscMinted(secondUser), secondUserDebt);
        assertEq(dsc.balanceOf(user), DSC_AMOUNT);
        assertEq(dsc.balanceOf(secondUser), secondUserDebt);
    }

    function testAccountValueAggregatesMultipleCollateralTokens() public {
        MockERC20 secondCollateral = new MockERC20();
        MockV3Aggregator secondPriceFeed = new MockV3Aggregator(FEED_DECIMALS, 1000e8);
        DecentralizedStableCoin multiCollateralDsc = new DecentralizedStableCoin();

        address[] memory tokenAddresses = new address[](2);
        address[] memory priceFeedAddresses = new address[](2);
        tokenAddresses[0] = address(collateral);
        tokenAddresses[1] = address(secondCollateral);
        priceFeedAddresses[0] = address(priceFeed);
        priceFeedAddresses[1] = address(secondPriceFeed);

        DSCEngine multiCollateralEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(multiCollateralDsc));
        multiCollateralDsc.transferOwnership(address(multiCollateralEngine));

        uint256 tokenAmount = 5 ether;
        collateral.mint(user, tokenAmount);
        secondCollateral.mint(user, tokenAmount);
        vm.startPrank(user);
        collateral.approve(address(multiCollateralEngine), tokenAmount);
        secondCollateral.approve(address(multiCollateralEngine), tokenAmount);
        multiCollateralEngine.depositCollateral(address(collateral), tokenAmount);
        multiCollateralEngine.depositCollateral(address(secondCollateral), tokenAmount);
        multiCollateralEngine.mintDsc(2000 ether);
        vm.stopPrank();

        assertEq(multiCollateralEngine.getAccountCollateralValue(user), 15_000 ether);
        assertEq(multiCollateralEngine.getHealthFactor(user), 3.75e18);
        assertEq(multiCollateralDsc.balanceOf(user), 2000 ether);
    }
}
