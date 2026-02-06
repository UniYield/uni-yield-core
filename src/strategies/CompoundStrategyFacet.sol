// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategyFacet} from "../interfaces/IStrategyFacet.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";
import {SafeERC20} from "../utils/SafeERC20.sol";
import {IComet} from "../interfaces/external/IComet.sol";

/// @notice Compound V3 Comet strategy: supplies vault asset (base token) to Comet. Deploy with Comet address; vault asset must equal comet.baseToken().
contract CompoundStrategyFacet is IStrategyFacet {
    using SafeERC20 for IERC20;

    bytes32 private immutable STRATEGY_ID;
    IComet private immutable COMET;

    constructor(address comet_) {
        STRATEGY_ID = bytes32(uint256(uint160(address(this))));
        COMET = IComet(comet_);
    }

    function strategyId() external view override returns (bytes32) {
        return STRATEGY_ID;
    }

    function totalManagedAssets() public view override returns (uint256) {
        if (address(COMET) == address(0)) return 0;
        return COMET.balanceOf(address(this));
    }

    function rateBps() public view override returns (uint256) {
        if (address(COMET) == address(0)) return 0;
        uint256 utilization = COMET.getUtilization();
        uint64 ratePerSec = COMET.getSupplyRate(utilization);
        return uint256(ratePerSec) * 31_536_000 * 10_000 / 1e18;
    }

    function depositToStrategy(uint256 assets) public override {
        if (assets == 0 || address(COMET) == address(0)) return;
        address asset = COMET.baseToken();
        SafeERC20.safeApprove(IERC20(asset), address(COMET), assets);
        COMET.supplyFrom(address(this), address(this), asset, assets);
    }

    function withdrawFromStrategy(uint256 assets) public override {
        if (assets == 0 || address(COMET) == address(0)) return;
        address asset = COMET.baseToken();
        COMET.withdrawFrom(address(this), address(this), asset, assets);
    }

    function exitStrategy() public override {
        if (address(COMET) == address(0)) return;
        address asset = COMET.baseToken();
        uint256 balance = COMET.balanceOf(address(this));
        if (balance > 0) {
            COMET.withdrawFrom(address(this), address(this), asset, balance);
        }
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
