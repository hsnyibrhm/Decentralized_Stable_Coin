// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockV3Aggregator} from "../src/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    uint256 private constant COLLATERAL_AMOUNT = 10 ether;
    uint256 private constant DSC_AMOUNT = 1000 ether;
    uint8 private constant FEED_DECIMALS = 8;
    int256 private constant ETH_USD_PRICE = 2000e8;

    DSCEngine private engine;
    DecentralizedStableCoin private dsc;
    MockERC20 private collateral;
    MockV3Aggregator private priceFeed;
    address private user = makeAddr("user");

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
        engine.depositCollateralAndMintDsc(
            address(collateral),
            COLLATERAL_AMOUNT,
            DSC_AMOUNT
        );

        assertEq(collateral.balanceOf(address(engine)), COLLATERAL_AMOUNT);
        assertEq(
            engine.getCollateralBalanceOfUser(user, address(collateral)),
            COLLATERAL_AMOUNT
        );
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
}
