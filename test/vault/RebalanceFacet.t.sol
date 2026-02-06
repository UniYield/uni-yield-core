// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UniYieldDiamond} from "../../src/UniYieldDiamond.sol";
import {MockERC20} from "../helpers/Mocks/MockERC20.sol";
import {MockStrategyFacet} from "../helpers/Mocks/MockStrategyFacet.sol";
import {MockStrategyFacetHighRate} from "../helpers/Mocks/MockStrategyFacetHighRate.sol";
import {DiamondDeployer} from "../helpers/DiamondDeployer.t.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";
import {Actors} from "../helpers/Actors.t.sol";

contract RebalanceFacetTest is Test, DiamondDeployer {
    UniYieldDiamond diamond;
    MockERC20 asset;
    MockStrategyFacet lowRateStrategy;
    MockStrategyFacetHighRate highRateStrategy;
    bytes32 lowRateId;
    bytes32 highRateId;

    function setUp() public {
        vm.deal(Actors.OWNER, 1 ether);
        diamond = deployDiamond(Actors.OWNER);
        vm.startPrank(Actors.OWNER);
        addLoupeFacet(diamond);
        addOwnershipFacet(diamond);
        addVaultCoreFacet(diamond);
        addStrategyRegistryFacet(diamond);
        addRebalanceFacet(diamond);

        lowRateStrategy = new MockStrategyFacet();
        highRateStrategy = new MockStrategyFacetHighRate();
        lowRateId = bytes32(uint256(uint160(address(lowRateStrategy))));
        highRateId = bytes32(uint256(uint160(address(highRateStrategy))));
        // Strategies are invoked via delegatecall, not added as facets.

        asset = new MockERC20("Test USDC", "USDC", 6);
        asset.mint(Actors.OWNER, 1_000_000e6);

        _initVault(address(asset), 6, "Vault", "vUSDC", 6, 50, lowRateId);
        IVault4626Diamond(address(diamond)).addStrategy(lowRateId, true, 10_000, 10_000);
        IVault4626Diamond(address(diamond)).addStrategy(highRateId, true, 10_000, 10_000);
        IVault4626Diamond(address(diamond)).setActiveStrategy(lowRateId);
        vm.stopPrank();
    }

    function _initVault(
        address asset_,
        uint8 assetDecimals_,
        string memory name_,
        string memory symbol_,
        uint8 shareDecimals_,
        uint16 minSwitchBps_,
        bytes32 activeStrategyId_
    ) internal {
        (bool ok,) = address(diamond).call(
            abi.encodeWithSignature(
                "initVault(address,uint8,string,string,uint8,uint16,bytes32)",
                asset_,
                assetDecimals_,
                name_,
                symbol_,
                shareDecimals_,
                minSwitchBps_,
                activeStrategyId_
            )
        );
        require(ok, "initVault failed");
    }

    function test_PreviewRebalance_ShowsSwitch() public view {
        (bytes32 fromId, bytes32 toId, uint256 assetsToMove) =
            IVault4626Diamond(address(diamond)).previewRebalance();
        assertEq(fromId, lowRateId);
        assertEq(toId, highRateId);
        assertEq(assetsToMove, 0);
    }

    function test_Rebalance_SwitchesToHigherRate() public {
        assertEq(IVault4626Diamond(address(diamond)).activeStrategyId(), lowRateId);
        vm.prank(Actors.OWNER);
        IVault4626Diamond(address(diamond)).rebalance();
        assertEq(IVault4626Diamond(address(diamond)).activeStrategyId(), highRateId);
    }

    function test_Rebalance_RevertsWhenNoBetterStrategy() public {
        vm.prank(Actors.OWNER);
        IVault4626Diamond(address(diamond)).setActiveStrategy(highRateId);
        vm.prank(Actors.OWNER);
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).rebalance();
    }
}
