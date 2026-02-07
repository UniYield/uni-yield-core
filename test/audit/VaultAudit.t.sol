// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseDiamondTest} from "../helpers/BaseDiamondTest.t.sol";
import {MockERC20} from "../helpers/Mocks/MockERC20.sol";
import {MockStrategyFacet} from "../helpers/Mocks/MockStrategyFacet.sol";
import {LibErrors} from "../../src/libraries/LibErrors.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";

/// @notice Audit regression tests: donation attack, rounding, reentrancy, depositReceived abuse
contract VaultAuditTest is BaseDiamondTest {
    address attacker;
    address victim;

    function setUp() public override {
        owner = address(0x1);
        user1 = address(0x666); // attacker
        user2 = address(0x777); // victim
        attacker = user1;
        victim = user2;

        vm.deal(owner, 1 ether);
        vm.deal(attacker, 1 ether);
        vm.deal(victim, 1 ether);

        diamond = deployDiamond(owner);
        vm.startPrank(owner);
        addLoupeFacet(diamond);
        addOwnershipFacet(diamond);
        addVaultCoreFacet(diamond);
        addStrategyRegistryFacet(diamond);
        addRebalanceFacet(diamond);

        mockStrategyFacet = new MockStrategyFacet();
        mockStrategyId = bytes32(uint256(uint160(address(mockStrategyFacet))));

        asset = new MockERC20("USDC", "USDC", 6);
        asset.mint(attacker, 1000e6 + 1); // attacker: 1 wei + donation
        asset.mint(victim, 1000e6);

        initVault(address(asset), 6, "Vault", "vUSDC", 6, 50, mockStrategyId);
        addStrategy(mockStrategyId, true, 10_000, 10_000);
        setActiveStrategy(mockStrategyId);
        vm.stopPrank();
    }

    /// @notice Donation/inflation attack: attacker deposits 1 wei, donates large amount, victim must receive meaningful shares
    function test_DonationAttack_VictimGetsMeaningfulShares() public {
        vm.startPrank(attacker);
        asset.approve(address(diamond), 1);
        IVault4626Diamond(address(diamond)).deposit(1, attacker);
        uint256 attackerShares = IVault4626Diamond(address(diamond)).balanceOf(attacker);
        assertGt(attackerShares, 0, "Attacker should get shares");

        asset.transfer(address(diamond), 1000e6); // Donation
        vm.stopPrank();

        vm.prank(victim);
        asset.approve(address(diamond), 1000e6);

        uint256 sharesBefore = IVault4626Diamond(address(diamond)).balanceOf(victim);
        vm.prank(victim);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(1000e6, victim);
        uint256 sharesAfter = IVault4626Diamond(address(diamond)).balanceOf(victim);

        assertGt(shares, 0, "Victim must receive shares after donation attack");
        assertGe(sharesAfter, sharesBefore + shares, "Victim shares increased");

        uint256 victimFraction =
            (sharesAfter * 1e18) / IVault4626Diamond(address(diamond)).totalSupply();
        assertGt(victimFraction, 0.5e18, "Victim should own majority after depositing 1000e6");
    }

    /// @notice Rounding: 1 wei deposit must mint shares
    function test_Rounding_SmallDeposit_MintsShares() public {
        asset.mint(victim, 1);
        vm.prank(victim);
        asset.approve(address(diamond), 1);
        vm.prank(victim);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(1, victim);
        assertGt(shares, 0, "1 wei deposit must mint shares");
    }

    /// @notice Rounding: redeem all shares should return ~totalAssets for that owner
    function test_Rounding_RedeemAll_MatchesProportionalAssets() public {
        vm.prank(victim);
        asset.approve(address(diamond), 100e6);
        vm.prank(victim);
        IVault4626Diamond(address(diamond)).deposit(100e6, victim);

        uint256 shares = IVault4626Diamond(address(diamond)).balanceOf(victim);
        uint256 assetsBefore = asset.balanceOf(victim);
        vm.prank(victim);
        uint256 assetsOut = IVault4626Diamond(address(diamond)).redeem(shares, victim, victim);
        uint256 assetsAfter = asset.balanceOf(victim);

        assertEq(IVault4626Diamond(address(diamond)).balanceOf(victim), 0);
        assertLe(assetsOut, 100e6 + 1, "Rounding should not over-distribute");
        assertGe(assetsAfter - assetsBefore, 99e6, "Victim should get ~100e6 back");
    }

    /// @notice Reentrancy: malicious strategy cannot reenter
    function test_Reentrancy_Deposit_Reverts() public {
        MaliciousStrategy malicious = new MaliciousStrategy(address(diamond));
        bytes32 maliciousId = bytes32(uint256(uint160(address(malicious))));
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).addStrategy(maliciousId, true, 10_000, 10_000);
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).setActiveStrategy(maliciousId);

        vm.prank(victim);
        asset.approve(address(diamond), 100e6);

        // Malicious strategy reenters -> inner deposit reverts ReentrantCall -> strategy delegatecall fails -> ExternalCallFailed
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ExternalCallFailed.selector, maliciousId));
        vm.prank(victim);
        IVault4626Diamond(address(diamond)).deposit(100e6, victim);
    }

    /// @notice depositReceived: anyone can mint shares for assets already in vault (by design for LI.FI)
    function test_DepositReceived_AnyoneCanMintForIdleBalance() public {
        vm.prank(victim);
        asset.approve(address(diamond), 100e6);
        vm.prank(victim);
        IVault4626Diamond(address(diamond)).deposit(100e6, victim);

        vm.prank(attacker);
        asset.transfer(address(diamond), 50e6);

        vm.prank(attacker);
        (uint256 shares,) = IVault4626Diamond(address(diamond)).depositReceived(
            attacker, 50e6, 0, block.timestamp + 3600
        );

        assertGt(shares, 0, "Attacker gets shares for transferred assets");
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(attacker), shares);
    }

    /// @notice Invariant: totalSupply proportional to totalAssets
    function test_Invariant_ShareAssetRatio_Consistent() public {
        vm.prank(victim);
        asset.approve(address(diamond), 100e6);
        vm.prank(victim);
        IVault4626Diamond(address(diamond)).deposit(100e6, victim);

        uint256 supply = IVault4626Diamond(address(diamond)).totalSupply();
        uint256 assets = IVault4626Diamond(address(diamond)).totalAssets();
        assertGe(supply, 1, "Supply > 0");
        assertGe(assets, 99e6, "Assets ~ 100e6");
        assertLe(assets, 101e6, "Assets ~ 100e6");
    }
}

/// @notice Malicious strategy that tries to reenter during depositToStrategy (runs via delegatecall)
contract MaliciousStrategy {
    address immutable vault;

    constructor(address vault_) {
        vault = vault_;
    }

    function depositToStrategy(uint256) external {
        IVault4626Diamond(vault).deposit(1, msg.sender);
    }

    function withdrawFromStrategy(uint256) external {}
    function exitStrategy() external {}
    function strategyId() external pure returns (bytes32) { return bytes32(0); }
    function totalManagedAssets() external pure returns (uint256) { return 0; }
    function rateBps() external pure returns (uint256) { return 0; }
    function strategyDeposit(uint256) external pure returns (uint256) { return 0; }
    function strategyWithdraw(uint256) external pure returns (uint256) { return 0; }
    function strategyTotalAssets() external pure returns (uint256) { return 0; }
    function strategyRateBps() external pure returns (uint256) { return 0; }
    function strategyExit() external pure returns (uint256) { return 0; }
}
