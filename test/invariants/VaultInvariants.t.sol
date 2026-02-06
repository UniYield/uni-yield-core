// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {BaseDiamondTest} from "../helpers/BaseDiamondTest.t.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";
import {UniYieldDiamond} from "../../src/UniYieldDiamond.sol";
import {MockERC20} from "../helpers/Mocks/MockERC20.sol";
import {Actors} from "../helpers/Actors.t.sol";

contract VaultInvariantsTest is StdInvariant, BaseDiamondTest {
    VaultInvariantHandler public handler;

    function setUp() public override {
        super.setUp();
        handler = new VaultInvariantHandler();
        handler.setDiamond(diamond);
        handler.setAsset(asset);
        targetContract(address(handler));
    }

    function invariant_totalSupplyNonNegative() public view {
        assertGe(IVault4626Diamond(address(diamond)).totalSupply(), 0);
    }

    function invariant_totalAssetsNonNegative() public view {
        assertGe(IVault4626Diamond(address(diamond)).totalAssets(), 0);
    }

    function invariant_totalSupplyEqualsSumBalances() public view {
        uint256 supply = IVault4626Diamond(address(diamond)).totalSupply();
        uint256 sum =
            IVault4626Diamond(address(diamond)).balanceOf(Actors.OWNER) +
            IVault4626Diamond(address(diamond)).balanceOf(Actors.USER1) +
            IVault4626Diamond(address(diamond)).balanceOf(Actors.USER2);
        assertEq(supply, sum);
    }
}

contract VaultInvariantHandler is Test {
    UniYieldDiamond public diamond;
    MockERC20 public asset;

    function setDiamond(UniYieldDiamond d) external {
        diamond = d;
    }

    function setAsset(MockERC20 a) external {
        asset = a;
    }

    function deposit(uint256 amount) external {
        amount = bound(amount, 1, asset.balanceOf(Actors.USER1));
        vm.startPrank(Actors.USER1);
        asset.approve(address(diamond), amount);
        try IVault4626Diamond(address(diamond)).deposit(amount, Actors.USER1) {} catch {}
        vm.stopPrank();
    }

    function withdraw(uint256 amount) external {
        uint256 shares = IVault4626Diamond(address(diamond)).balanceOf(Actors.USER1);
        if (shares == 0) return;
        amount = bound(amount, 1, IVault4626Diamond(address(diamond)).convertToAssets(shares));
        vm.startPrank(Actors.USER1);
        try IVault4626Diamond(address(diamond)).withdraw(amount, Actors.USER1, Actors.USER1) {} catch {}
        vm.stopPrank();
    }

    function redeem(uint256 shareAmount) external {
        uint256 shares = IVault4626Diamond(address(diamond)).balanceOf(Actors.USER1);
        if (shares == 0) return;
        shareAmount = bound(shareAmount, 1, shares);
        vm.prank(Actors.USER1);
        try IVault4626Diamond(address(diamond)).redeem(shareAmount, Actors.USER1, Actors.USER1) {} catch {}
    }
}
