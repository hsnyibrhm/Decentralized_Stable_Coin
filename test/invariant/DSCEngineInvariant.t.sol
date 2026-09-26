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

    DSCEngine private immutable engine;
    DecentralizedStableCoin private immutable dsc;
    MockERC20 private immutable collateral;
    address[3] public actors;

    constructor(DSCEngine engine_, DecentralizedStableCoin dsc_, MockERC20 collateral_) {
        engine = engine_;
        dsc = dsc_;
        collateral = collateral_;

        actors[0] = makeAddr("handlerActor0");
        actors[1] = makeAddr("handlerActor1");
        actors[2] = makeAddr("handlerActor2");

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            collateral.mint(actors[i], STARTING_COLLATERAL);
            vm.prank(actors[i]);
            collateral.approve(address(engine), type(uint256).max);
            vm.prank(actors[i]);
            dsc.approve(address(engine), type(uint256).max);
        }
    }

    function deposit(uint256 amountSeed, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
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

    function redeem(uint256 amountSeed, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 deposited = engine.getCollateralBalanceOfUser(actor, address(collateral));
        if (deposited == 0) return;

        uint256 maxAmount = deposited < MAX_ACTION_AMOUNT ? deposited : MAX_ACTION_AMOUNT;
        uint256 amount = bound(amountSeed, 1, maxAmount);
        vm.prank(actor);
        try engine.redeemCollateral(address(collateral), amount) { } catch { }
    }

    function _actor(uint256 actorSeed) private view returns (address) {
        return actors[actorSeed % ACTOR_COUNT];
    }
}

contract DSCEngineInvariantTest is Test {
    uint8 private constant FEED_DECIMALS = 8;
    int256 private constant COLLATERAL_PRICE = 2000e8;

    DSCEngine private engine;
    DecentralizedStableCoin private dsc;
    MockERC20 private collateral;
    DSCEngineHandler private handler;

    function setUp() public {
        collateral = new MockERC20();
        MockV3Aggregator priceFeed = new MockV3Aggregator(FEED_DECIMALS, COLLATERAL_PRICE);
        dsc = new DecentralizedStableCoin();

        address[] memory collateralTokens = new address[](1);
        address[] memory priceFeeds = new address[](1);
        collateralTokens[0] = address(collateral);
        priceFeeds[0] = address(priceFeed);
        engine = new DSCEngine(collateralTokens, priceFeeds, address(dsc));
        dsc.transferOwnership(address(engine));

        handler = new DSCEngineHandler(engine, dsc, collateral);
        targetContract(address(handler));
    }

    function invariant_DscSupplyEqualsTotalTrackedDebt() public view {
        uint256 totalDebt;
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); i++) {
            totalDebt += engine.getDscMinted(handler.actors(i));
        }
        assertEq(dsc.totalSupply(), totalDebt);
    }

    function invariant_ActorHealthFactorsRemainSafe() public view {
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); i++) {
            assertGe(engine.getHealthFactor(handler.actors(i)), engine.getMinHealthFactor());
        }
    }

    function invariant_EngineCollateralMatchesUserLedger() public view {
        uint256 totalRecordedCollateral;
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); i++) {
            totalRecordedCollateral += engine.getCollateralBalanceOfUser(handler.actors(i), address(collateral));
        }
        assertEq(collateral.balanceOf(address(engine)), totalRecordedCollateral);
    }
}
