// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { MockERC20 } from "../../src/mocks/MockERC20.sol";
import { MockV3Aggregator } from "../../src/mocks/MockV3Aggregator.sol";

contract DSCEngineHandler is Test {
    uint256 public constant ACTOR_COUNT = 3;
    uint256 private constant STARTING_COLLATERAL = 1_000_000 ether;
    uint256 private constant MAX_ACTION_AMOUNT = 1_000 ether;
    uint256 private constant MIN_ORACLE_PRICE = 1e8;
    uint256 private constant MAX_ORACLE_PRICE = 100_000e8;

    DSCEngine private immutable engine;
    DecentralizedStableCoin private immutable dsc;
    MockERC20 private immutable collateralA;
    MockERC20 private immutable collateralB;
    MockV3Aggregator private immutable priceFeedA;
    MockV3Aggregator private immutable priceFeedB;
    address[3] public actors;
    uint256 public burnFromAttempts;

    constructor(
        DSCEngine engine_,
        DecentralizedStableCoin dsc_,
        MockERC20 collateralA_,
        MockERC20 collateralB_,
        MockV3Aggregator priceFeedA_,
        MockV3Aggregator priceFeedB_
    ) {
        engine = engine_;
        dsc = dsc_;
        collateralA = collateralA_;
        collateralB = collateralB_;
        priceFeedA = priceFeedA_;
        priceFeedB = priceFeedB_;

        actors[0] = makeAddr("handlerActor0");
        actors[1] = makeAddr("handlerActor1");
        actors[2] = makeAddr("handlerActor2");

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            collateralA.mint(actors[i], STARTING_COLLATERAL);
            collateralB.mint(actors[i], STARTING_COLLATERAL);
            vm.prank(actors[i]);
            collateralA.approve(address(engine), type(uint256).max);
            vm.prank(actors[i]);
            collateralB.approve(address(engine), type(uint256).max);
            vm.prank(actors[i]);
            dsc.approve(address(engine), type(uint256).max);
            vm.prank(actors[i]);
            dsc.approve(address(this), type(uint256).max);
        }
    }

    function deposit(uint256 amountSeed, uint256 actorSeed, uint256 collateralSeed) external {
        address actor = _actor(actorSeed);
        MockERC20 collateral = _collateral(collateralSeed);
        uint256 balance = collateral.balanceOf(actor);
        if (balance == 0) return;

        uint256 maxAmount = balance < MAX_ACTION_AMOUNT ? balance : MAX_ACTION_AMOUNT;
        uint256 amount = bound(amountSeed, 1, maxAmount);
        vm.prank(actor);
        try engine.depositCollateral(address(collateral), amount) { } catch { }
    }

    function mint(uint256 amountSeed, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 amount = bound(amountSeed, 1, MAX_ACTION_AMOUNT);
        vm.prank(actor);
        try engine.mintDsc(amount) { } catch { }
    }

    function burn(uint256 amountSeed, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 debt = engine.getDscMinted(actor);
        uint256 balance = dsc.balanceOf(actor);
        uint256 maxAmount = debt < balance ? debt : balance;
        if (maxAmount == 0) return;

        uint256 amount = bound(amountSeed, 1, maxAmount);
        vm.prank(actor);
        try engine.burnDsc(amount) { } catch { }
    }

    function redeem(uint256 amountSeed, uint256 actorSeed, uint256 collateralSeed) external {
        address actor = _actor(actorSeed);
        MockERC20 collateral = _collateral(collateralSeed);
        uint256 deposited = engine.getCollateralBalanceOfUser(actor, address(collateral));
        if (deposited == 0) return;

        uint256 maxAmount = deposited < MAX_ACTION_AMOUNT ? deposited : MAX_ACTION_AMOUNT;
        uint256 amount = bound(amountSeed, 1, maxAmount);
        vm.prank(actor);
        try engine.redeemCollateral(address(collateral), amount) { } catch { }
    }

    function updatePrices(uint256 priceASeed, uint256 priceBSeed) external {
        uint256 priceA = bound(priceASeed, MIN_ORACLE_PRICE, MAX_ORACLE_PRICE);
        uint256 priceB = bound(priceBSeed, MIN_ORACLE_PRICE, MAX_ORACLE_PRICE);
        priceFeedA.updateAnswer(int256(priceA));
        priceFeedB.updateAnswer(int256(priceB));
    }

    function liquidate(uint256 debtSeed, uint256 userSeed, uint256 liquidatorSeed, uint256 collateralSeed) external {
        address user = _actor(userSeed);
        address liquidator = _actor(liquidatorSeed);
        if (user == liquidator) return;

        uint256 userDebt = engine.getDscMinted(user);
        uint256 liquidatorBalance = dsc.balanceOf(liquidator);
        uint256 maxDebtToCover = userDebt < liquidatorBalance ? userDebt : liquidatorBalance;
        if (maxDebtToCover == 0) return;

        uint256 debtToCover = bound(debtSeed, 1, maxDebtToCover);
        MockERC20 collateral = _collateral(collateralSeed);
        vm.prank(liquidator);
        try engine.liquidate(address(collateral), user, debtToCover) { } catch { }
    }

    function attemptBurnFrom(uint256 amountSeed, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 balance = dsc.balanceOf(actor);
        uint256 amount = bound(amountSeed, 1, balance == 0 ? 1 : balance);
        burnFromAttempts++;
        try dsc.burnFrom(actor, amount) { } catch { }
    }

    function collateralTokens(uint256 index) external view returns (address) {
        return address(_collateral(index));
    }

    function _collateral(uint256 seed) private view returns (MockERC20) {
        return seed % 2 == 0 ? collateralA : collateralB;
    }

    function _actor(uint256 actorSeed) private view returns (address) {
        return actors[actorSeed % ACTOR_COUNT];
    }
}

contract DSCEngineInvariantTest is Test {
    uint8 private constant FEED_DECIMALS = 8;
    int256 private constant COLLATERAL_A_PRICE = 2000e8;
    int256 private constant COLLATERAL_B_PRICE = 30_000e8;

    DSCEngine private engine;
    DecentralizedStableCoin private dsc;
    MockERC20 private collateralA;
    MockERC20 private collateralB;
    MockV3Aggregator private priceFeedA;
    DSCEngineHandler private handler;

    function setUp() public {
        collateralA = new MockERC20();
        collateralB = new MockERC20();
        priceFeedA = new MockV3Aggregator(FEED_DECIMALS, COLLATERAL_A_PRICE);
        MockV3Aggregator priceFeedB = new MockV3Aggregator(FEED_DECIMALS, COLLATERAL_B_PRICE);
        dsc = new DecentralizedStableCoin();

        address[] memory collateralTokens = new address[](2);
        address[] memory priceFeeds = new address[](2);
        collateralTokens[0] = address(collateralA);
        collateralTokens[1] = address(collateralB);
        priceFeeds[0] = address(priceFeedA);
        priceFeeds[1] = address(priceFeedB);
        engine = new DSCEngine(collateralTokens, priceFeeds, address(dsc));
        dsc.transferOwnership(address(engine));

        handler = new DSCEngineHandler(engine, dsc, collateralA, collateralB, priceFeedA, priceFeedB);
        targetContract(address(handler));
    }

    function invariant_DscSupplyEqualsTotalTrackedDebt() public view {
        uint256 totalDebt;
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); i++) {
            totalDebt += engine.getDscMinted(handler.actors(i));
        }
        assertEq(dsc.totalSupply(), totalDebt);
    }

    function invariant_EngineCollateralMatchesUserLedger() public view {
        _assertEngineCollateralMatchesUserLedger();
    }

    function testCollateralBalancesMatchLedgerAfterDepositRedeemAndLiquidation() public {
        address depositor = handler.actors(0);
        address liquidator = handler.actors(1);
        address borrower = handler.actors(2);

        vm.prank(depositor);
        engine.depositCollateral(address(collateralA), 10 ether);
        _assertEngineCollateralMatchesUserLedger();

        vm.prank(depositor);
        engine.redeemCollateral(address(collateralA), 5 ether);
        _assertEngineCollateralMatchesUserLedger();

        vm.prank(liquidator);
        engine.depositCollateral(address(collateralA), 3 ether);
        _assertEngineCollateralMatchesUserLedger();
        vm.prank(liquidator);
        engine.mintDsc(1_000 ether);
        vm.prank(borrower);
        engine.depositCollateral(address(collateralA), 2 ether);
        _assertEngineCollateralMatchesUserLedger();
        vm.prank(borrower);
        engine.mintDsc(1_000 ether);

        priceFeedA.updateAnswer(900e8);
        vm.prank(liquidator);
        engine.liquidate(address(collateralA), borrower, 100 ether);
        _assertEngineCollateralMatchesUserLedger();
    }

    function invariant_HealthFactorMatchesCurrentPricesAndTrackedDebt() public view {
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); i++) {
            address actor = handler.actors(i);
            uint256 expectedHealthFactor =
                engine.calculateHealthFactor(engine.getDscMinted(actor), engine.getAccountCollateralValue(actor));
            assertEq(engine.getHealthFactor(actor), expectedHealthFactor);
        }
    }

    function _assertEngineCollateralMatchesUserLedger() private view {
        for (uint256 j = 0; j < 2; j++) {
            address token = handler.collateralTokens(j);
            uint256 totalRecordedCollateral;
            for (uint256 i = 0; i < handler.ACTOR_COUNT(); i++) {
                totalRecordedCollateral += engine.getCollateralBalanceOfUser(handler.actors(i), token);
            }
            assertEq(MockERC20(token).balanceOf(address(engine)), totalRecordedCollateral);
        }
    }
}
