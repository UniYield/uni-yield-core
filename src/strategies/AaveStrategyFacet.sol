// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategyFacet} from "../interfaces/IStrategyFacet.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";
import {SafeERC20} from "../utils/SafeERC20.sol";
import {IAavePool} from "../interfaces/external/IAavePool.sol";

/// @notice Aave V3 strategy: supplies vault asset to Aave, receives aTokens. Deploy with pool and aToken for the vault asset.
contract AaveStrategyFacet is IStrategyFacet {
    using SafeERC20 for IERC20;

    bytes32 private immutable STRATEGY_ID;
    IAavePool private immutable POOL;
    address private immutable A_TOKEN;

    /// @param pool_ Aave V3 Pool. Pass address(0) for no-op (e.g. tests).
    /// @param aToken_ aToken for the vault asset. Pass address(0) for no-op.
    constructor(address pool_, address aToken_) {
        STRATEGY_ID = bytes32(uint256(uint160(address(this))));
        POOL = IAavePool(pool_);
        A_TOKEN = aToken_;
    }

    function strategyId() external view override returns (bytes32) {
        return STRATEGY_ID;
    }

    function totalManagedAssets() public view override returns (uint256) {
        if (A_TOKEN == address(0)) return 0;
        return IERC20(A_TOKEN).balanceOf(address(this));
    }

    function rateBps() public view override returns (uint256) {
        return 0;
    }

    function depositToStrategy(uint256 assets) public override {
        if (assets == 0) return;
        address asset = LibVaultStorage.vaultStorage().asset;
        if (asset == address(0)) return;
        SafeERC20.safeApprove(IERC20(asset), address(POOL), assets);
        POOL.supply(asset, assets, address(this), 0);
    }

    function withdrawFromStrategy(uint256 assets) public override {
        if (assets == 0) return;
        address asset = LibVaultStorage.vaultStorage().asset;
        if (asset == address(0)) return;
        POOL.withdraw(asset, assets, address(this));
    }

    function exitStrategy() public override {
        address asset = LibVaultStorage.vaultStorage().asset;
        if (asset == address(0)) return;
        POOL.withdraw(asset, type(uint256).max, address(this));
    }

    function strategyDeposit(uint256 assets) external override returns (uint256 deployedAssets) {
        uint256 balanceBefore = _assetBalance();
        depositToStrategy(assets);
        uint256 balanceAfter = _assetBalance();
        if (balanceBefore > balanceAfter) {
            deployedAssets = balanceBefore - balanceAfter;
        }
    }

    function strategyWithdraw(uint256 assets) external override returns (uint256 withdrawnAssets) {
        uint256 balanceBefore = _assetBalance();
        withdrawFromStrategy(assets);
        uint256 balanceAfter = _assetBalance();
        if (balanceAfter > balanceBefore) {
            withdrawnAssets = balanceAfter - balanceBefore;
        }
    }

    function strategyTotalAssets() external view override returns (uint256) {
        return totalManagedAssets();
    }

    function strategyRateBps() external view override returns (uint256) {
        return rateBps();
    }

    function strategyExit() external override returns (uint256 recoveredAssets) {
        uint256 balanceBefore = _assetBalance();
        exitStrategy();
        uint256 balanceAfter = _assetBalance();
        if (balanceAfter > balanceBefore) {
            recoveredAssets = balanceAfter - balanceBefore;
        }
    }

    function _assetBalance() internal view returns (uint256) {
        address asset = LibVaultStorage.vaultStorage().asset;
        if (asset == address(0)) return 0;
        return IERC20(asset).balanceOf(address(this));
    }
}
