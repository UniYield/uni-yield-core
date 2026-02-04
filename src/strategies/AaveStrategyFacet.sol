// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategyFacet} from "../interfaces/IStrategyFacet.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";

contract AaveStrategyFacet is IStrategyFacet {
    bytes32 private immutable STRATEGY_ID;

    constructor() {
        STRATEGY_ID = bytes32(uint256(uint160(address(this))));
    }

    function strategyId() external view override returns (bytes32) {
        return STRATEGY_ID;
    }

    function totalManagedAssets() public view override returns (uint256) {
        // TODO: read Aave positions and convert to USDC-equivalent using LibVaultStorage.vaultStorage().asset
        return 0;
    }

    function rateBps() public view override returns (uint256) {
        // TODO: fetch Aave supply APY for USDC and convert to bps
        return 0;
    }

    function depositToStrategy(uint256 assets) public override {
        if (assets == 0) return;
        // TODO: supply USDC to Aave using stored pool/provider addresses
    }

    function withdrawFromStrategy(uint256 assets) public override {
        if (assets == 0) return;
        // TODO: withdraw USDC from Aave
    }

    function exitStrategy() public override {
        // TODO: unwind all Aave positions back to idle USDC
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
