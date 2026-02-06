// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategyFacet} from "../interfaces/IStrategyFacet.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";
import {SafeERC20} from "../utils/SafeERC20.sol";
import {IMorpho, MarketParams} from "../interfaces/external/IMorpho.sol";

/// @notice Morpho Blue strategy: supplies vault asset as loan token to a Morpho market. Deploy with morpho + market params (loanToken must be vault asset).
contract MorphoStrategyFacet is IStrategyFacet {
    using SafeERC20 for IERC20;

    bytes32 private immutable STRATEGY_ID;
    IMorpho private immutable MORPHO;
    address private immutable LOAN_TOKEN;
    address private immutable COLLATERAL_TOKEN;
    address private immutable ORACLE;
    address private immutable IRM;
    uint256 private immutable LLTV;
    address private immutable VAULT;

    /// @param vault_ Diamond address for staticcall balance queries. Pass address(0) for delegatecall-only.
    constructor(
        address morpho_,
        address loanToken_,
        address collateralToken_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address vault_
    ) {
        STRATEGY_ID = bytes32(uint256(uint160(address(this))));
        MORPHO = IMorpho(morpho_);
        LOAN_TOKEN = loanToken_;
        COLLATERAL_TOKEN = collateralToken_;
        ORACLE = oracle_;
        IRM = irm_;
        LLTV = lltv_;
        VAULT = vault_;
    }

    function strategyId() external view override returns (bytes32) {
        return STRATEGY_ID;
    }

    function totalManagedAssets() public view override returns (uint256) {
        if (address(MORPHO) == address(0)) return 0;
        address target = VAULT != address(0) ? VAULT : address(this);
        (uint256 supplyShares,,) = MORPHO.position(_marketId(), target);
        if (supplyShares == 0) return 0;
        (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = MORPHO.market(_marketId());
        if (totalSupplyShares == 0) return 0;
        return uint256(supplyShares) * totalSupplyAssets / totalSupplyShares;
    }

    function rateBps() public view override returns (uint256) {
        return 0;
    }

    function depositToStrategy(uint256 assets) public override {
        if (assets == 0 || address(MORPHO) == address(0)) return;
        SafeERC20.safeApprove(IERC20(LOAN_TOKEN), address(MORPHO), assets);
        MarketParams memory params = _marketParams();
        MORPHO.supply(params, assets, 0, address(this), "");
    }

    function withdrawFromStrategy(uint256 assets) public override {
        if (assets == 0 || address(MORPHO) == address(0)) return;
        MarketParams memory params = _marketParams();
        MORPHO.withdraw(params, assets, 0, address(this), address(this));
    }

    function exitStrategy() public override {
        if (address(MORPHO) == address(0)) return;
        (uint256 supplyShares,,) = MORPHO.position(_marketId(), address(this));
        if (supplyShares == 0) return;
        MarketParams memory params = _marketParams();
        MORPHO.withdraw(params, 0, supplyShares, address(this), address(this));
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

    function _marketParams() internal view returns (MarketParams memory) {
        return MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
    }

    function _marketId() internal view returns (bytes32) {
        return keccak256(abi.encode(_marketParams()));
    }

    function _assetBalance() internal view returns (uint256) {
        address asset = LibVaultStorage.vaultStorage().asset;
        if (asset == address(0)) return 0;
        return IERC20(asset).balanceOf(address(this));
    }
}
