// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AaveStrategyFacet} from "../../src/strategies/AaveStrategyFacet.sol";
import {IStrategyFacet} from "../../src/interfaces/IStrategyFacet.sol";

/// @notice Aave strategy facet tests. Uses zero addresses for pool/aToken (no-op mode).
contract AaveStrategyFacetTest is Test {
    AaveStrategyFacet strategy;

    function setUp() public {
        strategy = new AaveStrategyFacet(address(0), address(0), address(0));
    }

    function test_StrategyId() public view {
        assertEq(strategy.strategyId(), bytes32(uint256(uint160(address(strategy)))));
    }

    function test_TotalManagedAssets_ZeroWhenNoPool() public view {
        assertEq(strategy.totalManagedAssets(), 0);
    }

    function test_RateBps() public view {
        assertEq(strategy.rateBps(), 0);
    }

    function test_DepositToStrategy_NoRevertWhenZeroAddressPool() public {
        strategy.depositToStrategy(1000e6);
    }

    function test_WithdrawFromStrategy_NoRevertWhenZeroAddressPool() public {
        strategy.withdrawFromStrategy(500e6);
    }

    function test_ExitStrategy_NoRevertWhenZeroAddressPool() public {
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

    function test_StrategyTotalAssets() public view {
        assertEq(strategy.strategyTotalAssets(), 0);
    }

    function test_StrategyRateBps() public view {
        assertEq(strategy.strategyRateBps(), 0);
    }
}
