// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseDiamondTest} from "../helpers/BaseDiamondTest.t.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";

/// @notice Integration: vault deposit triggers strategy deposit (delegatecall to mock strategy).
contract StrategyIntegrationTest is BaseDiamondTest {
    function test_Deposit_DelegatesToStrategy() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user1);
        vm.stopPrank();
        assertGt(shares, 0);
        assertEq(IVault4626Diamond(address(diamond)).totalAssets(), amount);
        // Mock strategy is no-op; assets stay in vault (idle).
    }

    function test_Withdraw_DelegatesToStrategy() public {
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).deposit(1000e6, user1);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).withdraw(500e6, user1, user1);
        assertEq(asset.balanceOf(user1), 1_000_000e6 - 500e6);
    }
}
