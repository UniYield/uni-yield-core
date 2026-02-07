// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UniYieldDiamond} from "../../src/UniYieldDiamond.sol";
import {MockERC20} from "./Mocks/MockERC20.sol";
import {MockStrategyFacet} from "./Mocks/MockStrategyFacet.sol";
import {DiamondDeployer} from "./DiamondDeployer.t.sol";
import {Actors} from "./Actors.t.sol";
import {LibVaultStorage} from "../../src/libraries/LibVaultStorage.sol";

/// @notice Base test with full diamond (all facets), initialized vault, mock strategy, and mock asset.
abstract contract BaseDiamondTest is Test, DiamondDeployer {
    UniYieldDiamond internal diamond;
    MockERC20 internal asset;
    MockStrategyFacet internal mockStrategyFacet;
    bytes32 internal mockStrategyId;

    address internal owner;
    address internal user1;
    address internal user2;

    function setUp() public virtual {
        owner = Actors.OWNER;
        user1 = Actors.USER1;
        user2 = Actors.USER2;
        vm.deal(owner, 1 ether);

        diamond = deployDiamond(owner);
        vm.startPrank(owner);
        addLoupeFacet(diamond);
        addOwnershipFacet(diamond);
        addVaultCoreFacet(diamond);
        addStrategyRegistryFacet(diamond);
        addRebalanceFacet(diamond);

        mockStrategyFacet = new MockStrategyFacet();
        mockStrategyId = bytes32(uint256(uint160(address(mockStrategyFacet))));
        // Strategy is invoked via delegatecall to strategy address, not as a facet.

        asset = new MockERC20("Test USDC", "USDC", 6);
        asset.mint(user1, 1_000_000e6);
        asset.mint(user2, 1_000_000e6);

        initVault(address(asset), 6, "UniYield Vault", "uvUSDC", 0, 50, mockStrategyId);
        addStrategy(mockStrategyId, true, 10_000, 10_000);
        setActiveStrategy(mockStrategyId);
        vm.stopPrank();
    }

    function initVault(
        address asset_,
        uint8 assetDecimals_,
        string memory name_,
        string memory symbol_,
        uint8 decimalsOffset_,
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
                decimalsOffset_,
                minSwitchBps_,
                activeStrategyId_
            )
        );
        require(ok, "initVault failed");
    }

    function addStrategy(bytes32 id, bool enabled, uint16 targetBps, uint16 maxBps) internal {
        (bool ok,) = address(diamond).call(
            abi.encodeWithSignature("addStrategy(bytes32,bool,uint16,uint16)", id, enabled, targetBps, maxBps)
        );
        require(ok, "addStrategy failed");
    }

    function setActiveStrategy(bytes32 id) internal {
        (bool ok,) = address(diamond).call(abi.encodeWithSignature("setActiveStrategy(bytes32)", id));
        require(ok, "setActiveStrategy failed");
    }
}
