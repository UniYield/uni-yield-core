// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {BaseDiamondTest} from "../helpers/BaseDiamondTest.t.sol";
import {UniYieldDiamond} from "../../src/UniYieldDiamond.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";
import {Actors} from "../helpers/Actors.t.sol";

/// @notice Invariant: after rebalance, active strategy remains in registry; previewRebalance consistent.
contract RebalanceInvariantsTest is StdInvariant, BaseDiamondTest {
    RebalanceInvariantHandler public handler;

    function setUp() public override {
        super.setUp();
        handler = new RebalanceInvariantHandler();
        handler.setDiamond(diamond);
        targetContract(address(handler));
    }

    function invariant_activeStrategyInIdsAfterRebalance() public view {
        bytes32 active = IVault4626Diamond(address(diamond)).activeStrategyId();
        bytes32[] memory ids = IVault4626Diamond(address(diamond)).getStrategyIds();
        if (active == bytes32(0)) return;
        bool found;
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == active) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function invariant_previewRebalanceFromEqualsActive() public view {
        (bytes32 fromId,,) = IVault4626Diamond(address(diamond)).previewRebalance();
        assertEq(fromId, IVault4626Diamond(address(diamond)).activeStrategyId());
    }
}

contract RebalanceInvariantHandler is Test {
    UniYieldDiamond public diamond;

    function setDiamond(UniYieldDiamond d) external {
        diamond = d;
    }

    function rebalance() external {
        vm.prank(Actors.OWNER);
        try IVault4626Diamond(address(diamond)).rebalance() {} catch {}
    }
}
