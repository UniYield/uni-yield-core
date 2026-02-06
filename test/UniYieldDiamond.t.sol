// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
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
import {LibVaultStorage} from "../src/libraries/LibVaultStorage.sol";
import {MockERC20} from "./helpers/MockERC20.sol";
import {MockStrategyFacet} from "./helpers/MockStrategyFacet.sol";
import {MockStrategyFacetHighRate} from "./helpers/MockStrategyFacetHighRate.sol";
import {DiamondSelectors} from "./helpers/DiamondSelectors.sol";

contract UniYieldDiamondTest is Test, DiamondSelectors {
    UniYieldDiamond diamond;
    address owner;
    address user1;
    address user2;

    DiamondCutFacet cutFacet;
    DiamondLoupeFacet loupeFacet;
    DiamondOwnershipFacet ownershipFacet;
    VaultCoreFacet vaultCoreFacet;
    StrategyRegistryFacet strategyRegistryFacet;
    RebalanceFacet rebalanceFacet;
    MockStrategyFacet mockStrategyFacet;

    MockERC20 asset;
    bytes32 mockStrategyId;

    function setUp() public {
        owner = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);

        vm.deal(owner, 1 ether);

        cutFacet = new DiamondCutFacet();
        diamond = new UniYieldDiamond(owner, address(cutFacet));

        loupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new DiamondOwnershipFacet();
        vaultCoreFacet = new VaultCoreFacet();
        strategyRegistryFacet = new StrategyRegistryFacet();
        rebalanceFacet = new RebalanceFacet();
        mockStrategyFacet = new MockStrategyFacet();
        mockStrategyId = bytes32(uint256(uint160(address(mockStrategyFacet))));

        vm.startPrank(owner);
        _addFacet(address(loupeFacet), diamondLoupeSelectors());
        _addFacet(address(ownershipFacet), ownershipSelectors());
        _addFacet(address(vaultCoreFacet), vaultCoreSelectors());
        _addFacet(address(strategyRegistryFacet), strategyRegistrySelectors());
        _addFacet(address(rebalanceFacet), rebalanceSelectors());
        // Strategy is not added as a facet; vault delegatecalls to strategy contract directly.

        asset = new MockERC20("Test USDC", "USDC", 6);
        asset.mint(user1, 1_000_000e6);
        asset.mint(user2, 1_000_000e6);

        IVault(address(diamond)).initVault(
            address(asset),
            6,
            "UniYield Vault",
            "uvUSDC",
            6,
            50, // minSwitchBps 0.5%
            mockStrategyId
        );
        IVault(address(diamond)).addStrategy(mockStrategyId, true, 10_000, 10_000);
        IVault(address(diamond)).setActiveStrategy(mockStrategyId);
        vm.stopPrank();
    }

    function _addFacet(address facet, bytes4[] memory selectors) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        (bool ok,) =
            address(diamond).call(abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cuts, address(0), ""));
        require(ok, "diamondCut failed");
    }

    // ---- Diamond infrastructure ----
    function test_Owner() public view {
        assertEq(IOwnership(address(diamond)).owner(), owner);
    }

    function test_TransferOwnership() public {
        vm.prank(owner);
        IOwnership(address(diamond)).transferOwnership(user1);
        assertEq(IOwnership(address(diamond)).owner(), user1);
    }

    function test_TransferOwnership_RevertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        IOwnership(address(diamond)).transferOwnership(user2);
    }

    function test_Facets() public view {
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(address(diamond)).facets();
        assertGt(facets.length, 5);
        bool hasLoupe;
        for (uint256 i = 0; i < facets.length; i++) {
            if (facets[i].facetAddress == address(loupeFacet)) hasLoupe = true;
        }
        assertTrue(hasLoupe);
    }

    function test_FacetAddress() public view {
        address a = IDiamondLoupe(address(diamond)).facetAddress(DiamondCutFacet.diamondCut.selector);
        assertEq(a, address(cutFacet));
    }

    function test_SupportsInterface() public view {
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IERC165).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IDiamondCut).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IDiamondLoupe).interfaceId));
    }

    // ---- Vault ERC20 / metadata ----
    function test_VaultMetadata() public view {
        assertEq(IVault(address(diamond)).name(), "UniYield Vault");
        assertEq(IVault(address(diamond)).symbol(), "uvUSDC");
        assertEq(IVault(address(diamond)).decimals(), 6);
        assertEq(IVault(address(diamond)).asset(), address(asset));
    }

    function test_InitVault_RevertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).initVault(address(asset), 6, "X", "X", 6, 0, bytes32(0));
    }

    // ---- Vault ERC-4626 deposit / withdraw ----
    function test_Deposit() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        uint256 shares = IVault(address(diamond)).deposit(amount, user1);
        vm.stopPrank();
        assertGt(shares, 0);
        assertEq(IVault(address(diamond)).balanceOf(user1), shares);
        assertEq(IVault(address(diamond)).totalSupply(), shares);
        assertEq(IVault(address(diamond)).totalAssets(), amount);
        assertEq(asset.balanceOf(address(diamond)), amount);
    }

    function test_Mint() public {
        uint256 sharesDesired = 500e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), type(uint256).max);
        uint256 assets = IVault(address(diamond)).mint(sharesDesired, user1);
        vm.stopPrank();
        assertGt(assets, 0);
        uint256 shares = IVault(address(diamond)).balanceOf(user1);
        assertEq(shares, sharesDesired);
        assertEq(IVault(address(diamond)).totalAssets(), assets);
    }

    function test_Withdraw() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        uint256 shares = IVault(address(diamond)).deposit(amount, user1);
        uint256 assetsOut = IVault(address(diamond)).convertToAssets(shares);
        uint256 sharesBurned = IVault(address(diamond)).withdraw(assetsOut, user1, user1);
        vm.stopPrank();
        assertEq(sharesBurned, shares);
        assertEq(asset.balanceOf(user1), 1_000_000e6);
        assertEq(IVault(address(diamond)).balanceOf(user1), 0);
        assertEq(IVault(address(diamond)).totalSupply(), 0);
    }

    function test_Redeem() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        uint256 shares = IVault(address(diamond)).deposit(amount, user1);
        uint256 assetsOut = IVault(address(diamond)).redeem(shares, user1, user1);
        vm.stopPrank();
        assertGt(assetsOut, 0);
        assertEq(IVault(address(diamond)).balanceOf(user1), 0);
        assertEq(IVault(address(diamond)).totalSupply(), 0);
    }

    function test_Deposit_RevertsOnZeroAssets() public {
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).deposit(0, user1);
    }

    function test_ConvertToSharesAndAssets() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        IVault(address(diamond)).deposit(amount, user1);
        vm.stopPrank();
        uint256 shares = IVault(address(diamond)).balanceOf(user1);
        assertEq(IVault(address(diamond)).convertToAssets(shares), amount);
        assertEq(IVault(address(diamond)).convertToShares(amount), shares);
    }

    function test_DepositReceived() public {
        uint256 amount = 500e6;
        uint256 minShares = 1;
        uint256 deadline = block.timestamp + 3600;
        vm.startPrank(user1);
        asset.transfer(address(diamond), amount);
        (uint256 shares, uint256 assetsReceived) =
            IVault(address(diamond)).depositReceived(user1, amount, minShares, deadline);
        vm.stopPrank();
        assertGt(shares, 0);
        assertEq(assetsReceived, amount);
        assertEq(IVault(address(diamond)).balanceOf(user1), shares);
        assertEq(IVault(address(diamond)).totalSupply(), shares);
    }

    function test_DepositReceived_AfterDeposit() public {
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        IVault(address(diamond)).deposit(1000e6, user1);
        uint256 amount = 300e6;
        vm.prank(user2);
        asset.transfer(address(diamond), amount);
        uint256 minShares = IVault(address(diamond)).convertToShares(amount) - 1;
        uint256 deadline = block.timestamp + 3600;
        vm.prank(user2);
        (uint256 shares, uint256 assetsReceived) =
            IVault(address(diamond)).depositReceived(user2, amount, minShares, deadline);
        assertEq(assetsReceived, amount);
        assertGt(shares, 0);
        assertEq(IVault(address(diamond)).balanceOf(user2), shares);
    }

    function test_DepositReceived_RevertsWhenInsufficientIdle() public {
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        IVault(address(diamond)).deposit(1000e6, user1);
        uint256 amount = 2000e6;
        uint256 deadline = block.timestamp + 3600;
        vm.prank(user2);
        vm.expectRevert();
        IVault(address(diamond)).depositReceived(user2, amount, 0, deadline);
    }

    function test_DepositReceived_RevertsWhenDeadlineExpired() public {
        vm.prank(user1);
        asset.transfer(address(diamond), 100e6);
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).depositReceived(user1, 100e6, 0, block.timestamp - 1);
    }

    function test_DepositReceived_RevertsWhenSlippage() public {
        vm.prank(user1);
        asset.transfer(address(diamond), 100e6);
        uint256 minShares = type(uint256).max;
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).depositReceived(user1, 100e6, minShares, block.timestamp + 3600);
    }

    // ---- Pause ----
    function test_Pause_Unpause() public {
        vm.prank(owner);
        IVault(address(diamond)).pause();
        vm.prank(user1);
        asset.approve(address(diamond), 1000e6);
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).deposit(1000e6, user1);
        vm.prank(owner);
        IVault(address(diamond)).unpause();
        vm.prank(user1);
        uint256 shares = IVault(address(diamond)).deposit(1000e6, user1);
        assertGt(shares, 0);
    }

    function test_Pause_RevertsDepositMintWithdrawRedeem() public {
        vm.prank(owner);
        IVault(address(diamond)).pause();
        vm.prank(user1);
        asset.approve(address(diamond), type(uint256).max);
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).deposit(100e6, user1);
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).mint(100e6, user1);
        vm.prank(owner);
        IVault(address(diamond)).unpause();
        vm.prank(user1);
        IVault(address(diamond)).deposit(100e6, user1);
        vm.prank(owner);
        IVault(address(diamond)).pause();
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).withdraw(50e6, user1, user1);
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).redeem(50e6, user1, user1);
    }

    function test_Pause_RevertsDepositReceived() public {
        vm.prank(user1);
        asset.transfer(address(diamond), 100e6);
        vm.prank(owner);
        IVault(address(diamond)).pause();
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).depositReceived(user1, 100e6, 0, block.timestamp + 3600);
    }

    function test_Pause_RevertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).pause();
        vm.prank(user1);
        vm.expectRevert();
        IVault(address(diamond)).unpause();
    }

    // ---- Strategy registry ----
    function test_StrategyRegistry() public view {
        assertEq(IVault(address(diamond)).activeStrategyId(), mockStrategyId);
        bytes32[] memory ids = IVault(address(diamond)).getStrategyIds();
        assertEq(ids.length, 1);
        assertEq(ids[0], mockStrategyId);
        LibVaultStorage.StrategyConfig memory cfg = IVault(address(diamond)).getStrategyConfig(mockStrategyId);
        assertTrue(cfg.enabled);
        assertEq(cfg.targetBps, 10_000);
        assertEq(cfg.maxBps, 10_000);
    }

    function test_SetActiveStrategy_RevertsWhenDisabled() public {
        vm.prank(owner);
        IVault(address(diamond)).setStrategyEnabled(mockStrategyId, false);
        vm.prank(owner);
        vm.expectRevert();
        IVault(address(diamond)).setActiveStrategy(mockStrategyId);
    }

    function test_PreviewRebalance() public view {
        (bytes32 fromId, bytes32 toId, uint256 assetsToMove) = IVault(address(diamond)).previewRebalance();
        assertEq(fromId, mockStrategyId);
        assertEq(toId, mockStrategyId);
        assertEq(assetsToMove, 0);
    }

    // ---- Transfer / allowance ----
    function test_Transfer() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        IVault(address(diamond)).deposit(amount, user1);
        IVault(address(diamond)).transfer(user2, IVault(address(diamond)).balanceOf(user1));
        vm.stopPrank();
        assertEq(IVault(address(diamond)).balanceOf(user2), IVault(address(diamond)).totalSupply());
        assertEq(IVault(address(diamond)).balanceOf(user1), 0);
    }

    function test_ApproveAndTransferFrom() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        asset.approve(address(diamond), amount);
        IVault(address(diamond)).deposit(amount, user1);
        uint256 shares = IVault(address(diamond)).balanceOf(user1);
        IVault(address(diamond)).approve(user2, shares);
        vm.stopPrank();
        vm.prank(user2);
        IVault(address(diamond)).transferFrom(user1, user2, shares);
        assertEq(IVault(address(diamond)).balanceOf(user2), shares);
        assertEq(IVault(address(diamond)).balanceOf(user1), 0);
    }
}

interface IVault {
    function initVault(
        address asset_,
        uint8 assetDecimals_,
        string calldata name_,
        string calldata symbol_,
        uint8 shareDecimals_,
        uint16 minSwitchBps_,
        bytes32 activeStrategyId_
    ) external;

    function addStrategy(bytes32 id, bool enabled, uint16 targetBps, uint16 maxBps) external;

    function setActiveStrategy(bytes32 id) external;

    function setStrategyEnabled(bytes32 id, bool enabled) external;

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function asset() external view returns (address);

    function totalAssets() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);

    function convertToShares(uint256) external view returns (uint256);

    function convertToAssets(uint256) external view returns (uint256);

    function deposit(uint256, address) external returns (uint256);

    function mint(uint256, address) external returns (uint256);

    function withdraw(uint256, address, address) external returns (uint256);

    function redeem(uint256, address, address) external returns (uint256);

    function depositReceived(address receiver, uint256 amount, uint256 minShares, uint256 deadline)
        external
        returns (uint256 shares, uint256 assetsReceived);

    function activeStrategyId() external view returns (bytes32);

    function getStrategyIds() external view returns (bytes32[] memory);

    function getStrategyConfig(bytes32) external view returns (LibVaultStorage.StrategyConfig memory);

    function rebalance() external;

    function previewRebalance() external view returns (bytes32 fromId, bytes32 toId, uint256 assetsToMove);

    function pause() external;
    function unpause() external;
}

interface IOwnership {
    function owner() external view returns (address);

    function transferOwnership(address) external;
}

// ---- Rebalance test with two strategies ----
contract RebalanceTest is Test, DiamondSelectors {
    UniYieldDiamond diamond;
    address owner;
    MockERC20 asset;
    MockStrategyFacet lowRateStrategy;
    MockStrategyFacetHighRate highRateStrategy;
    bytes32 lowRateId;
    bytes32 highRateId;

    function setUp() public {
        owner = address(0x1);
        vm.deal(owner, 1 ether);

        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new UniYieldDiamond(owner, address(cutFacet));

        vm.startPrank(owner);
        _addFacet(address(new DiamondLoupeFacet()), diamondLoupeSelectors());
        _addFacet(address(new DiamondOwnershipFacet()), ownershipSelectors());
        _addFacet(address(new VaultCoreFacet()), vaultCoreSelectors());
        _addFacet(address(new StrategyRegistryFacet()), strategyRegistrySelectors());
        _addFacet(address(new RebalanceFacet()), rebalanceSelectors());

        lowRateStrategy = new MockStrategyFacet();
        highRateStrategy = new MockStrategyFacetHighRate();
        lowRateId = bytes32(uint256(uint160(address(lowRateStrategy))));
        highRateId = bytes32(uint256(uint160(address(highRateStrategy))));

        asset = new MockERC20("Test USDC", "USDC", 6);
        asset.mint(owner, 1_000_000e6);

        IVault(address(diamond)).initVault(address(asset), 6, "Vault", "vUSDC", 6, 50, lowRateId);
        IVault(address(diamond)).addStrategy(lowRateId, true, 10_000, 10_000);
        IVault(address(diamond)).addStrategy(highRateId, true, 10_000, 10_000);
        IVault(address(diamond)).setActiveStrategy(lowRateId);
        vm.stopPrank();
    }

    function _addFacet(address facet, bytes4[] memory selectors) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        (bool ok,) =
            address(diamond).call(abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cuts, address(0), ""));
        require(ok, "diamondCut failed");
    }

    function test_Rebalance_SwitchesToHigherRate() public {
        assertEq(IVault(address(diamond)).activeStrategyId(), lowRateId);

        vm.prank(owner);
        IVault(address(diamond)).rebalance();

        assertEq(IVault(address(diamond)).activeStrategyId(), highRateId);
    }

    function test_PreviewRebalance_ShowsSwitch() public view {
        (bytes32 fromId, bytes32 toId, uint256 assetsToMove) = IVault(address(diamond)).previewRebalance();
        assertEq(fromId, lowRateId);
        assertEq(toId, highRateId);
        assertEq(assetsToMove, 0);
    }
}
