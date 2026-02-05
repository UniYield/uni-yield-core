// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {UniYieldDiamond} from "../src/UniYieldDiamond.sol";
import {DiamondCutFacet} from "../src/diamond/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/DiamondLoupeFacet.sol";
import {DiamondOwnershipFacet} from "../src/diamond/DiamondOwnershipFacet.sol";
import {VaultCoreFacet} from "../src/vault/VaultCoreFacet.sol";
import {StrategyRegistryFacet} from "../src/vault/StrategyRegistryFacet.sol";
import {RebalanceFacet} from "../src/vault/RebalanceFacet.sol";

/// @notice Deploys UniYield diamond and all core facets, then performs diamondCut to wire them.
contract DeployDiamond is Script {
    function run() external returns (address diamond_, address owner_) {
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0));
        if (deployerKey != 0) {
            owner_ = vm.addr(deployerKey);
            vm.startBroadcast(deployerKey);
        } else {
            owner_ = vm.envOr("CONTRACT_OWNER", address(0x1));
            // No startBroadcast: dry-run only; prank used for diamondCut simulation
        }

        DiamondCutFacet cutFacet = new DiamondCutFacet();
        UniYieldDiamond diamond = new UniYieldDiamond(owner_, address(cutFacet));
        diamond_ = address(diamond);

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        DiamondOwnershipFacet ownershipFacet = new DiamondOwnershipFacet();
        VaultCoreFacet vaultCoreFacet = new VaultCoreFacet();
        StrategyRegistryFacet strategyRegistryFacet = new StrategyRegistryFacet();
        RebalanceFacet rebalanceFacet = new RebalanceFacet();

        if (deployerKey != 0) {
            vm.broadcast(deployerKey);
            _diamondCut(diamond_, address(loupeFacet), _loupeSelectors(), IDiamondCut.FacetCutAction.Add);
            vm.broadcast(deployerKey);
            _diamondCut(diamond_, address(ownershipFacet), _ownershipSelectors(), IDiamondCut.FacetCutAction.Add);
            vm.broadcast(deployerKey);
            _diamondCut(diamond_, address(vaultCoreFacet), _vaultCoreSelectors(), IDiamondCut.FacetCutAction.Add);
            vm.broadcast(deployerKey);
            _diamondCut(
                diamond_, address(strategyRegistryFacet), _strategyRegistrySelectors(), IDiamondCut.FacetCutAction.Add
            );
            vm.broadcast(deployerKey);
            _diamondCut(diamond_, address(rebalanceFacet), _rebalanceSelectors(), IDiamondCut.FacetCutAction.Add);
        } else {
            vm.prank(owner_);
            _diamondCut(diamond_, address(loupeFacet), _loupeSelectors(), IDiamondCut.FacetCutAction.Add);
            vm.prank(owner_);
            _diamondCut(diamond_, address(ownershipFacet), _ownershipSelectors(), IDiamondCut.FacetCutAction.Add);
            vm.prank(owner_);
            _diamondCut(diamond_, address(vaultCoreFacet), _vaultCoreSelectors(), IDiamondCut.FacetCutAction.Add);
            vm.prank(owner_);
            _diamondCut(
                diamond_, address(strategyRegistryFacet), _strategyRegistrySelectors(), IDiamondCut.FacetCutAction.Add
            );
            vm.prank(owner_);
            _diamondCut(diamond_, address(rebalanceFacet), _rebalanceSelectors(), IDiamondCut.FacetCutAction.Add);
        }

        if (deployerKey != 0) vm.stopBroadcast();

        console.log("UniYieldDiamond", diamond_);
        console.log("Owner", owner_);
        console.log("DiamondCutFacet", address(cutFacet));
        console.log("DiamondLoupeFacet", address(loupeFacet));
        console.log("DiamondOwnershipFacet", address(ownershipFacet));
        console.log("VaultCoreFacet", address(vaultCoreFacet));
        console.log("StrategyRegistryFacet", address(strategyRegistryFacet));
        console.log("RebalanceFacet", address(rebalanceFacet));
    }

    function _diamondCut(address diamond, address facet, bytes4[] memory selectors, IDiamondCut.FacetCutAction action)
        internal
    {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({facetAddress: facet, action: action, functionSelectors: selectors});
        (bool ok,) = diamond.call(abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cuts, address(0), ""));
        require(ok, "diamondCut failed");
    }

    function _loupeSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](5);
        s[0] = IDiamondLoupe.facets.selector;
        s[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        s[2] = IDiamondLoupe.facetAddresses.selector;
        s[3] = IDiamondLoupe.facetAddress.selector;
        s[4] = IERC165.supportsInterface.selector;
    }

    function _ownershipSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = DiamondOwnershipFacet.owner.selector;
        s[1] = DiamondOwnershipFacet.transferOwnership.selector;
    }

    function _vaultCoreSelectors() internal pure returns (bytes4[] memory s) {
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

    function _strategyRegistrySelectors() internal pure returns (bytes4[] memory s) {
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

    function _rebalanceSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = RebalanceFacet.rebalance.selector;
        s[1] = RebalanceFacet.previewRebalance.selector;
    }
}
