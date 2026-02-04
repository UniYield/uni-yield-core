// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategyFacet {
    /// @notice Unique id for registry (e.g., keccak256("AAVE_V3_USDC_BASE"))
    function strategyId() external view returns (bytes32);

    /// @notice Deposit `assets` of the vault asset into the venue.
    /// @dev Vault calls this via delegatecall through the diamond.
    function strategyDeposit(uint256 assets) external returns (uint256 deployedAssets);

    /// @notice Withdraw up to `assets` back to the vault.
    function strategyWithdraw(uint256 assets) external returns (uint256 withdrawnAssets);

    /// @notice Total underlying assets (USDC-equivalent) managed by this strategy.
    function strategyTotalAssets() external view returns (uint256);

    /// @notice Current net rate in bps (optional but useful for optimizer)
    function strategyRateBps() external view returns (uint256);

    /// @notice Emergency unwind (pull everything back if possible)
    function strategyExit() external returns (uint256 recoveredAssets);

    function totalManagedAssets() external view returns (uint256);

    function rateBps() external view returns (uint256);

    function depositToStrategy(uint256 assets) external;

    function withdrawFromStrategy(uint256 assets) external;

    function exitStrategy() external;
}
