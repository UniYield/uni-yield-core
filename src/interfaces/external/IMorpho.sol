// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

/// @notice Minimal Morpho Blue interface for supply/withdraw (supply = supply liquidity as loanToken).
interface IMorpho {
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalfOf,
        bytes memory data
    ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalfOf,
        address receiver
    ) external returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn);
    function supplyShares(
        MarketParams memory marketParams,
        uint256 shares,
        address onBehalfOf,
        bytes memory data
    ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);
    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalfOf,
        bytes memory data
    ) external;
    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalfOf,
        address receiver
    ) external;
    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );
}
