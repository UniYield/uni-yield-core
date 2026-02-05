// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../../src/interfaces/IERC165.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "../../src/diamond/DiamondCutFacet.sol";
import {DiamondOwnershipFacet} from "../../src/diamond/DiamondOwnershipFacet.sol";
import {VaultCoreFacet} from "../../src/vault/VaultCoreFacet.sol";
import {StrategyRegistryFacet} from "../../src/vault/StrategyRegistryFacet.sol";
import {RebalanceFacet} from "../../src/vault/RebalanceFacet.sol";
import {AaveStrategyFacet} from "../../src/strategies/AaveStrategyFacet.sol";
import {MockStrategyFacet} from "./MockStrategyFacet.sol";

/// @notice Returns function selectors for diamond cuts.
contract DiamondSelectors {
    function diamondCutSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](1);
        s[0] = IDiamondCut.diamondCut.selector;
    }

    function diamondLoupeSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](5);
        s[0] = IDiamondLoupe.facets.selector;
        s[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        s[2] = IDiamondLoupe.facetAddresses.selector;
        s[3] = IDiamondLoupe.facetAddress.selector;
        s[4] = IERC165.supportsInterface.selector;
    }

    function ownershipSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = DiamondOwnershipFacet.owner.selector;
        s[1] = DiamondOwnershipFacet.transferOwnership.selector;
    }

    function vaultCoreSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](19);
        s[0] = VaultCoreFacet.initVault.selector;
        s[1] = VaultCoreFacet.name.selector;
        s[2] = VaultCoreFacet.symbol.selector;
        s[3] = VaultCoreFacet.decimals.selector;
        s[4] = VaultCoreFacet.totalSupply.selector;
        s[5] = VaultCoreFacet.balanceOf.selector;
        s[6] = VaultCoreFacet.allowance.selector;
        s[7] = VaultCoreFacet.approve.selector;
        s[8] = VaultCoreFacet.transfer.selector;
        s[9] = VaultCoreFacet.transferFrom.selector;
        s[10] = VaultCoreFacet.asset.selector;
        s[11] = VaultCoreFacet.totalAssets.selector;
        s[12] = VaultCoreFacet.convertToShares.selector;
        s[13] = VaultCoreFacet.convertToAssets.selector;
        s[14] = VaultCoreFacet.deposit.selector;
        s[15] = VaultCoreFacet.mint.selector;
        s[16] = VaultCoreFacet.withdraw.selector;
        s[17] = VaultCoreFacet.redeem.selector;
        s[18] = VaultCoreFacet.depositReceived.selector;
    }

    function strategyRegistrySelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](8);
        s[0] = StrategyRegistryFacet.addStrategy.selector;
        s[1] = StrategyRegistryFacet.removeStrategy.selector;
        s[2] = StrategyRegistryFacet.setStrategyEnabled.selector;
        s[3] = StrategyRegistryFacet.setStrategyTargets.selector;
        s[4] = StrategyRegistryFacet.setActiveStrategy.selector;
        s[5] = StrategyRegistryFacet.activeStrategyId.selector;
        s[6] = StrategyRegistryFacet.getStrategyIds.selector;
        s[7] = StrategyRegistryFacet.getStrategyConfig.selector;
    }

    function rebalanceSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = RebalanceFacet.rebalance.selector;
        s[1] = RebalanceFacet.previewRebalance.selector;
    }

    function aaveStrategySelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](11);
        s[0] = AaveStrategyFacet.strategyId.selector;
        s[1] = AaveStrategyFacet.totalManagedAssets.selector;
        s[2] = AaveStrategyFacet.rateBps.selector;
        s[3] = AaveStrategyFacet.depositToStrategy.selector;
        s[4] = AaveStrategyFacet.withdrawFromStrategy.selector;
        s[5] = AaveStrategyFacet.exitStrategy.selector;
        s[6] = AaveStrategyFacet.strategyDeposit.selector;
        s[7] = AaveStrategyFacet.strategyWithdraw.selector;
        s[8] = AaveStrategyFacet.strategyTotalAssets.selector;
        s[9] = AaveStrategyFacet.strategyRateBps.selector;
        s[10] = AaveStrategyFacet.strategyExit.selector;
    }

    function mockStrategySelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](11);
        s[0] = MockStrategyFacet.strategyId.selector;
        s[1] = MockStrategyFacet.totalManagedAssets.selector;
        s[2] = MockStrategyFacet.rateBps.selector;
        s[3] = MockStrategyFacet.depositToStrategy.selector;
        s[4] = MockStrategyFacet.withdrawFromStrategy.selector;
        s[5] = MockStrategyFacet.exitStrategy.selector;
        s[6] = MockStrategyFacet.strategyDeposit.selector;
        s[7] = MockStrategyFacet.strategyWithdraw.selector;
        s[8] = MockStrategyFacet.strategyTotalAssets.selector;
        s[9] = MockStrategyFacet.strategyRateBps.selector;
        s[10] = MockStrategyFacet.strategyExit.selector;
    }
}
