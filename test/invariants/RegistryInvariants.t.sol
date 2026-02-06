// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {BaseDiamondTest} from "../helpers/BaseDiamondTest.t.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";
import {UniYieldDiamond} from "../../src/UniYieldDiamond.sol";
import {LibVaultStorage} from "../../src/libraries/LibVaultStorage.sol";
import {Actors} from "../helpers/Actors.t.sol";

/// @notice Invariant: activeStrategyId is in getStrategyIds and is enabled when non-zero.
contract RegistryInvariantsTest is StdInvariant, BaseDiamondTest {
    RegistryInvariantHandler public handler;

    function setUp() public override {
        super.setUp();
        handler = new RegistryInvariantHandler();
        handler.setDiamond(diamond);
        targetContract(address(handler));
    }

    function invariant_activeStrategyInRegistryOrZero() public view {
        bytes32 active = IVault4626Diamond(address(diamond)).activeStrategyId();
        if (active == bytes32(0)) return;
        bytes32[] memory ids = IVault4626Diamond(address(diamond)).getStrategyIds();
        bool found;
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == active) {
                found = true;
                break;
            }
        }
        assertTrue(found, "activeStrategyId must be in getStrategyIds");
    }

    function invariant_activeStrategyEnabledWhenNonZero() public view {
        bytes32 active = IVault4626Diamond(address(diamond)).activeStrategyId();
        if (active == bytes32(0)) return;
        LibVaultStorage.StrategyConfig memory cfg = IVault4626Diamond(address(diamond)).getStrategyConfig(active);
        assertTrue(cfg.enabled, "active strategy must be enabled");
    }

    function invariant_strategyConfigBpsValid() public view {
        bytes32[] memory ids = IVault4626Diamond(address(diamond)).getStrategyIds();
        for (uint256 i = 0; i < ids.length; i++) {
            LibVaultStorage.StrategyConfig memory cfg = IVault4626Diamond(address(diamond)).getStrategyConfig(ids[i]);
            assertLe(cfg.targetBps, 10_000);
            assertLe(cfg.maxBps, 10_000);
            assertLe(cfg.targetBps, cfg.maxBps);
        }
    }
}

contract RegistryInvariantHandler is Test {
    UniYieldDiamond public diamond;

    function setDiamond(UniYieldDiamond d) external {
        diamond = d;
    }

    function setActiveStrategy(bytes32 id) external {
        vm.prank(Actors.OWNER);
        try IVault4626Diamond(address(diamond)).setActiveStrategy(id) {} catch {}
    }

    function setStrategyEnabled(bytes32 id, bool enabled) external {
        vm.prank(Actors.OWNER);
        try IVault4626Diamond(address(diamond)).setStrategyEnabled(id, enabled) {} catch {}
    }
}
