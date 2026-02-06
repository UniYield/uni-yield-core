// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MorphoStrategyFacet} from "../../src/strategies/MorphoStrategyFacet.sol";
import {IStrategyFacet} from "../../src/interfaces/IStrategyFacet.sol";

/// @notice Morpho strategy facet tests. Uses zero address for Morpho (no-op paths).
contract MorphoStrategyFacetTest is Test {
    MorphoStrategyFacet strategy;

    function setUp() public {
        strategy = new MorphoStrategyFacet(
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            0,
            address(0)
        );
    }

    function test_StrategyId() public view {
        assertEq(strategy.strategyId(), bytes32(uint256(uint160(address(strategy)))));
    }

    function test_TotalManagedAssets_ZeroWhenNoMorpho() public view {
        assertEq(strategy.totalManagedAssets(), 0);
    }

    function test_RateBps() public view {
        assertEq(strategy.rateBps(), 0);
    }

    function test_DepositToStrategy_NoRevertWhenZeroMorpho() public {
        strategy.depositToStrategy(1000e6);
    }

    function test_WithdrawFromStrategy_NoRevertWhenZeroMorpho() public {
        strategy.withdrawFromStrategy(500e6);
    }

    function test_ExitStrategy_NoRevertWhenZeroMorpho() public {
        strategy.exitStrategy();
    }

    function test_StrategyDeposit_ReturnsZero() public {
        assertEq(strategy.strategyDeposit(1000e6), 0);
    }

    function test_StrategyWithdraw_ReturnsZero() public {
        assertEq(strategy.strategyWithdraw(500e6), 0);
    }

    function test_StrategyExit_ReturnsZero() public {
        assertEq(strategy.strategyExit(), 0);
    }
}
