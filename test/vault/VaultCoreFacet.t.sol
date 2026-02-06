// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseDiamondTest} from "../helpers/BaseDiamondTest.t.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";
import {LibVaultStorage} from "../../src/libraries/LibVaultStorage.sol";
import {Actors} from "../helpers/Actors.t.sol";

contract VaultCoreFacetTest is BaseDiamondTest {
    function test_Metadata() public view {
        assertEq(IVault4626Diamond(address(diamond)).name(), "UniYield Vault");
        assertEq(IVault4626Diamond(address(diamond)).symbol(), "uvUSDC");
        assertEq(IVault4626Diamond(address(diamond)).decimals(), 6);
        assertEq(IVault4626Diamond(address(diamond)).asset(), address(asset));
    }

    function test_Deposit() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user1);
        vm.stopPrank();
        assertGt(shares, 0);
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user1), shares);
        assertEq(IVault4626Diamond(address(diamond)).totalSupply(), shares);
        assertEq(IVault4626Diamond(address(diamond)).totalAssets(), amount);
    }

    function test_Mint() public {
        uint256 sharesDesired = 500e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), type(uint256).max);
        uint256 assets = IVault4626Diamond(address(diamond)).mint(sharesDesired, user1);
        vm.stopPrank();
        assertGt(assets, 0);
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user1), sharesDesired);
    }

    function test_Withdraw() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user1);
        uint256 assetsOut = IVault4626Diamond(address(diamond)).convertToAssets(shares);
        IVault4626Diamond(address(diamond)).withdraw(assetsOut, user1, user1);
        vm.stopPrank();
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user1), 0);
        assertEq(IVault4626Diamond(address(diamond)).totalSupply(), 0);
    }

    function test_Redeem() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user1);
        IVault4626Diamond(address(diamond)).redeem(shares, user1, user1);
        vm.stopPrank();
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user1), 0);
    }

    function test_ConvertToSharesAndAssets() public {
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).deposit(1000e6, user1);
        uint256 shares = IVault4626Diamond(address(diamond)).balanceOf(user1);
        assertEq(IVault4626Diamond(address(diamond)).convertToAssets(shares), 1000e6);
        assertEq(IVault4626Diamond(address(diamond)).convertToShares(1000e6), shares);
    }

    function test_Deposit_RevertsOnZeroAssets() public {
        vm.prank(user1);
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).deposit(0, user1);
    }

    function test_DepositReceived() public {
        uint256 amount = 500e6;
        vm.prank(user1);
        asset.transfer(address(diamond), amount);
        vm.prank(user1);
        (uint256 shares, uint256 assetsReceived) =
            IVault4626Diamond(address(diamond)).depositReceived(user1, amount, 0, block.timestamp + 3600);
        assertGt(shares, 0);
        assertEq(assetsReceived, amount);
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user1), shares);
    }

    function test_Pause_Unpause() public {
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).pause();
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).deposit(1000e6, user1);
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).unpause();
        vm.prank(user1);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(1000e6, user1);
        assertGt(shares, 0);
    }

    function test_Pause_RevertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).pause();
    }

    function test_Transfer() public {
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).deposit(1000e6, user1);
        uint256 bal = IVault4626Diamond(address(diamond)).balanceOf(user1);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).transfer(user2, bal);
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user2), bal);
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user1), 0);
    }

    function test_ApproveAndTransferFrom() public {
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).deposit(1000e6, user1);
        uint256 shares = IVault4626Diamond(address(diamond)).balanceOf(user1);
        vm.prank(user1);
        IVault4626Diamond(address(diamond)).approve(user2, shares);
        vm.prank(user2);
        IVault4626Diamond(address(diamond)).transferFrom(user1, user2, shares);
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user2), shares);
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user1), 0);
    }
}
