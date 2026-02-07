// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../../src/interfaces/IERC165.sol";
import {UniYieldDiamond} from "../../src/UniYieldDiamond.sol";
import {DiamondCutFacet} from "../../src/diamond/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";
import {DiamondOwnershipFacet} from "../../src/diamond/DiamondOwnershipFacet.sol";
import {VaultCoreFacet} from "../../src/vault/VaultCoreFacet.sol";
import {StrategyRegistryFacet} from "../../src/vault/StrategyRegistryFacet.sol";
import {RebalanceFacet} from "../../src/vault/RebalanceFacet.sol";
import {AaveStrategyFacet} from "../../src/strategies/AaveStrategyFacet.sol";
import {CompoundStrategyFacet} from "../../src/strategies/CompoundStrategyFacet.sol";
import {MorphoStrategyFacet} from "../../src/strategies/MorphoStrategyFacet.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {IVault4626Diamond} from "../../src/interfaces/IVault4626Diamond.sol";

/// @notice Fork test: vault + Aave V3, Compound V3, Morpho Blue on Ethereum.
/// Requires RPC_URL in .env (e.g. devnet or mainnet). Protocol addresses from .env or defaults.
/// Morpho test runs only if MORPHO_ORACLE is set (get from docs.morpho.org).
/// Run: forge test --match-path "test/fork/*.t.sol" -vvv
contract EthereumIntegrationForkTest is Test {
    UniYieldDiamond diamond;
    address owner = address(0x1);
    address user = address(0x2);

    // Ethereum mainnet defaults (override via .env)
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;

    address aavePool;
    address aaveAToken;
    address compoundComet;
    address morpho;
    address morphoLoanToken;
    address morphoCollateralToken;
    address morphoOracle;
    address morphoIrm;
    uint256 morphoLltv;

    AaveStrategyFacet aaveStrategy;
    CompoundStrategyFacet compoundStrategy;
    MorphoStrategyFacet morphoStrategy;

    bytes32 aaveStrategyId;
    bytes32 compoundStrategyId;
    bytes32 morphoStrategyId;

    function setUp() public {
        string memory rpcUrl = vm.envOr("RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true);
            return;
        }

        uint256 forkBlock = vm.envOr("FORK_BLOCK", uint256(20_000_000));
        vm.createSelectFork(rpcUrl, forkBlock);

        aavePool = vm.envOr("AAVE_POOL", address(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2));
        aaveAToken = vm.envOr("AAVE_A_TOKEN", address(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c));
        compoundComet = vm.envOr("COMPOUND_COMET", address(0xc3d688B66703497DAA19211EEdff47f25384cdc3));
        morpho = vm.envOr("MORPHO", address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb));
        morphoLoanToken = vm.envOr("MORPHO_LOAN_TOKEN", USDC);
        morphoCollateralToken = vm.envOr("MORPHO_COLLATERAL_TOKEN", address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        morphoOracle = vm.envOr("MORPHO_ORACLE", address(0));
        morphoIrm = vm.envOr("MORPHO_IRM", address(0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC));
        morphoLltv = vm.envOr("MORPHO_LLTV", uint256(860000000000000000));

        _deployDiamond();
        _deployStrategies();
        _initVault();
    }

    function _deployDiamond() internal {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new UniYieldDiamond(owner, address(cutFacet));

        vm.startPrank(owner);
        _addFacet(address(new DiamondLoupeFacet()), _loupeSelectors());
        _addFacet(address(new DiamondOwnershipFacet()), _ownershipSelectors());
        _addFacet(address(new VaultCoreFacet()), _vaultCoreSelectors());
        _addFacet(address(new StrategyRegistryFacet()), _strategyRegistrySelectors());
        _addFacet(address(new RebalanceFacet()), _rebalanceSelectors());
        vm.stopPrank();
    }

    function _deployStrategies() internal {
        aaveStrategy = new AaveStrategyFacet(aavePool, aaveAToken, address(diamond));
        compoundStrategy = new CompoundStrategyFacet(compoundComet, address(diamond));
        aaveStrategyId = bytes32(uint256(uint160(address(aaveStrategy))));
        compoundStrategyId = bytes32(uint256(uint160(address(compoundStrategy))));

        if (morphoOracle != address(0)) {
            morphoStrategy = new MorphoStrategyFacet(
                morpho, morphoLoanToken, morphoCollateralToken, morphoOracle, morphoIrm, morphoLltv, address(diamond)
            );
            morphoStrategyId = bytes32(uint256(uint160(address(morphoStrategy))));
        }
    }

    function _initVault() internal {
        vm.startPrank(owner);
        (bool ok,) = address(diamond).call(
            abi.encodeWithSignature(
                "initVault(address,uint8,string,string,uint8,uint16,bytes32)",
                USDC,
                6,
                "UniYield USDC",
                "uvUSDC",
                6,
                50,
                aaveStrategyId
            )
        );
        require(ok, "initVault failed");

        IVault4626Diamond(address(diamond)).addStrategy(aaveStrategyId, true, 10_000, 10_000);
        IVault4626Diamond(address(diamond)).addStrategy(compoundStrategyId, true, 10_000, 10_000);
        if (morphoStrategyId != bytes32(0)) {
            IVault4626Diamond(address(diamond)).addStrategy(morphoStrategyId, true, 10_000, 10_000);
        }
        IVault4626Diamond(address(diamond)).setActiveStrategy(aaveStrategyId);
        vm.stopPrank();
    }

    function _addFacet(address facet, bytes4[] memory selectors) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        (bool ok,) = address(diamond).call(abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cuts, address(0), ""));
        require(ok, "diamondCut failed");
    }

    function _fundUser(uint256 amount) internal {
        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(user, amount);
    }

    function test_AaveV3_DepositWithdraw() public {
        if (address(diamond) == address(0)) return; // skipped
        uint256 amount = 10_000e6;
        _fundUser(amount);

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user);
        vm.stopPrank();

        assertGt(shares, 0);
        assertGe(IVault4626Diamond(address(diamond)).totalAssets(), amount - 1); // allow 1 wei rounding from protocol
        assertEq(IVault4626Diamond(address(diamond)).balanceOf(user), shares);

        uint256 assetsBefore = IERC20(USDC).balanceOf(user);
        vm.prank(user);
        IVault4626Diamond(address(diamond)).redeem(shares, user, user);
        uint256 assetsAfter = IERC20(USDC).balanceOf(user);
        assertGe(assetsAfter - assetsBefore, amount - 1); // allow 1 wei rounding
    }

    function test_CompoundV3_DepositWithdraw() public {
        if (address(diamond) == address(0)) return;
        uint256 amount = 10_000e6;
        _fundUser(amount);

        vm.startPrank(owner);
        IVault4626Diamond(address(diamond)).setActiveStrategy(compoundStrategyId);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user);
        vm.stopPrank();

        assertGt(shares, 0);
        assertGe(IVault4626Diamond(address(diamond)).totalAssets(), amount - 1); // allow 1 wei rounding

        vm.prank(user);
        IVault4626Diamond(address(diamond)).redeem(shares, user, user);
        assertGe(IERC20(USDC).balanceOf(user), amount - 1);
    }

    function test_MorphoBlue_DepositWithdraw() public {
        if (address(diamond) == address(0) || morphoStrategyId == bytes32(0)) {
            vm.skip(true);
            return;
        }
        uint256 amount = 10_000e6;
        _fundUser(amount);

        vm.startPrank(owner);
        IVault4626Diamond(address(diamond)).setActiveStrategy(morphoStrategyId);
        vm.stopPrank();

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user);
        vm.stopPrank();

        assertGt(shares, 0);
        assertGe(IVault4626Diamond(address(diamond)).totalAssets(), amount - 1); // allow 1 wei rounding

        vm.prank(user);
        IVault4626Diamond(address(diamond)).redeem(shares, user, user);
        assertGe(IERC20(USDC).balanceOf(user), amount - 1);
    }

    function test_Rebalance_SwitchStrategy() public {
        if (address(diamond) == address(0)) return;
        uint256 amount = 5_000e6;
        _fundUser(amount);

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), amount);
        uint256 shares = IVault4626Diamond(address(diamond)).deposit(amount, user);
        vm.stopPrank();

        assertEq(IVault4626Diamond(address(diamond)).activeStrategyId(), aaveStrategyId);
        assertGe(IVault4626Diamond(address(diamond)).totalAssets(), amount - 1); // allow 1 wei rounding

        (bytes32 fromId, bytes32 toId,) = IVault4626Diamond(address(diamond)).previewRebalance();
        if (toId != fromId) {
            vm.prank(owner);
            IVault4626Diamond(address(diamond)).rebalance();
        }

        vm.prank(user);
        IVault4626Diamond(address(diamond)).redeem(shares, user, user);
        assertGe(IERC20(USDC).balanceOf(user), amount - 1);
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
        s = new bytes4[](29);
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
        s[19] = VaultCoreFacet.pause.selector;
        s[20] = VaultCoreFacet.unpause.selector;
        s[21] = VaultCoreFacet.previewDeposit.selector;
        s[22] = VaultCoreFacet.previewMint.selector;
        s[23] = VaultCoreFacet.previewWithdraw.selector;
        s[24] = VaultCoreFacet.previewRedeem.selector;
        s[25] = VaultCoreFacet.maxDeposit.selector;
        s[26] = VaultCoreFacet.maxMint.selector;
        s[27] = VaultCoreFacet.maxWithdraw.selector;
        s[28] = VaultCoreFacet.maxRedeem.selector;
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
