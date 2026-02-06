// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseDiamondTest} from "../helpers/BaseDiamondTest.t.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";
import {LibVaultStorage} from "../../src/libraries/LibVaultStorage.sol";
import {MockStrategyFacet} from "../helpers/Mocks/MockStrategyFacet.sol";
import {MockStrategyFacetHighRate} from "../helpers/Mocks/MockStrategyFacetHighRate.sol";
import {Actors} from "../helpers/Actors.t.sol";

contract StrategyRegistryFacetTest is BaseDiamondTest {
    MockStrategyFacetHighRate highRateStrategy;
    bytes32 highRateId;

    function setUp() public override {
        super.setUp();
        highRateStrategy = new MockStrategyFacetHighRate();
        highRateId = bytes32(uint256(uint160(address(highRateStrategy))));
    }

    function test_RegistryState() public view {
        assertEq(IVault4626Diamond(address(diamond)).activeStrategyId(), mockStrategyId);
        bytes32[] memory ids = IVault4626Diamond(address(diamond)).getStrategyIds();
        assertEq(ids.length, 1);
        assertEq(ids[0], mockStrategyId);
        LibVaultStorage.StrategyConfig memory cfg =
            IVault4626Diamond(address(diamond)).getStrategyConfig(mockStrategyId);
        assertTrue(cfg.enabled);
        assertEq(cfg.targetBps, 10_000);
        assertEq(cfg.maxBps, 10_000);
    }

    function test_AddStrategy() public {
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).addStrategy(highRateId, true, 5000, 10_000);
        bytes32[] memory ids = IVault4626Diamond(address(diamond)).getStrategyIds();
        assertEq(ids.length, 2);
        LibVaultStorage.StrategyConfig memory cfg =
            IVault4626Diamond(address(diamond)).getStrategyConfig(highRateId);
        assertTrue(cfg.enabled);
        assertEq(cfg.targetBps, 5000);
        assertEq(cfg.maxBps, 10_000);
    }

    function test_AddStrategy_RevertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).addStrategy(highRateId, true, 5000, 10_000);
    }

    function test_SetActiveStrategy() public {
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).addStrategy(highRateId, true, 10_000, 10_000);
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).setActiveStrategy(highRateId);
        assertEq(IVault4626Diamond(address(diamond)).activeStrategyId(), highRateId);
    }

    function test_SetActiveStrategy_RevertsWhenDisabled() public {
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).addStrategy(highRateId, false, 10_000, 10_000);
        vm.prank(owner);
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).setActiveStrategy(highRateId);
    }

    function test_SetStrategyEnabled() public {
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).setStrategyEnabled(mockStrategyId, false);
        LibVaultStorage.StrategyConfig memory cfg =
            IVault4626Diamond(address(diamond)).getStrategyConfig(mockStrategyId);
        assertFalse(cfg.enabled);
    }

    function test_SetStrategyTargets() public {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = mockStrategyId;
        uint16[] memory targetBps = new uint16[](1);
        targetBps[0] = 8000;
        uint16[] memory maxBps = new uint16[](1);
        maxBps[0] = 9000;
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).setStrategyTargets(ids, targetBps, maxBps);
        LibVaultStorage.StrategyConfig memory cfg =
            IVault4626Diamond(address(diamond)).getStrategyConfig(mockStrategyId);
        assertEq(cfg.targetBps, 8000);
        assertEq(cfg.maxBps, 9000);
    }

    function test_RemoveStrategy() public {
        vm.prank(owner);
        IVault4626Diamond(address(diamond)).removeStrategy(mockStrategyId);
        bytes32[] memory ids = IVault4626Diamond(address(diamond)).getStrategyIds();
        assertEq(ids.length, 0);
        assertEq(IVault4626Diamond(address(diamond)).activeStrategyId(), bytes32(0));
    }

    function test_RemoveStrategy_RevertsWhenNotFound() public {
        vm.prank(owner);
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).removeStrategy(bytes32(uint256(1)));
    }

    function test_GetStrategyConfig_RevertsWhenNotFound() public {
        vm.expectRevert();
        IVault4626Diamond(address(diamond)).getStrategyConfig(bytes32(uint256(1)));
    }
}
