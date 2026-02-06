// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CompoundStrategyFacet} from "../../src/strategies/CompoundStrategyFacet.sol";
import {IStrategyFacet} from "../../src/interfaces/IStrategyFacet.sol";

/// @notice Compound strategy facet tests. Uses zero address for Comet (no-op / revert-safe paths).
contract CompoundStrategyFacetTest is Test {
    CompoundStrategyFacet strategy;

    function setUp() public {
        strategy = new CompoundStrategyFacet(address(0));
    }

    function test_StrategyId() public view {
        assertEq(strategy.strategyId(), bytes32(uint256(uint160(address(strategy)))));
    }

    function test_TotalManagedAssets_ZeroWhenNoComet() public view {
        assertEq(strategy.totalManagedAssets(), 0);
    }

    function test_RateBps_ZeroWhenNoComet() public view {
        assertEq(strategy.rateBps(), 0);
    }

    function test_DepositToStrategy_NoRevertWhenZeroComet() public {
        strategy.depositToStrategy(1000e6);
    }

    function test_WithdrawFromStrategy_NoRevertWhenZeroComet() public {
        strategy.withdrawFromStrategy(500e6);
    }

    function test_ExitStrategy_NoRevertWhenZeroComet() public {
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
