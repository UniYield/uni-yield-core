// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseDiamondTest} from "../helpers/BaseDiamondTest.t.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";
import {LibVaultStorage} from "../../src/libraries/LibVaultStorage.sol";
import {Actors} from "../helpers/Actors.t.sol";

/// @notice End-to-end vault flows: deposit -> rebalance -> withdraw, multi-user, pause.
contract VaultIntegrationTest is BaseDiamondTest {
    function test_Flow_DepositWithdraw() public {
        uint256 amount = 5000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user1);
        assertEq(IVault4626Diamond(address(diamond)).totalAssets(), amount);
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user1), shares);
        IVault4626Diamond(address(diamond)).redeem(shares, user1, user1);
        assertEq(IVault4626Diamond(address(diamond)).totalSupply(), 0);
        assertEq(asset.balanceOf(user1), 1_000_000e6);
        vm.stopPrank();
    }

    function test_Flow_TwoUsersDeposit() public {
        vm.prank(user1);
        asset.approve(address(diamond), 3000e6);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).deposit(3000e6, user1);

        vm.prank(user2);
        asset.approve(address(diamond), 2000e6);
        vm.prank(user2);
        IVault4626Diamond(address(diamond)).deposit(2000e6, user2);

        assertEq(IVault4626Diamond(address(diamond)).totalAssets(), 5000e6);
        assertEq(IVault4626Diamond(address(diamond)).totalSupply(), IVault4626Diamond(address(diamond)).balanceOf(user1) + IVault4626Diamond(address(diamond)).balanceOf(user2));
    }

    function test_Flow_DepositThenWithdraw() public {
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(1000e6, user1);
        assertGt(shares, 0);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).redeem(shares, user1, user1);
        assertEq(asset.balanceOf(user1), 1_000_000e6);
    }

    function test_Flow_PauseDepositUnpauseDeposit() public {
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).pause();
        vm.prank(user1);
        asset.approve(address(diamond), 100e6);
        vm.prank(user1);
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).deposit(100e6, user1);
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).unpause();
        vm.prank(user1);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(100e6, user1);
        assertGt(shares, 0);
    }
}
