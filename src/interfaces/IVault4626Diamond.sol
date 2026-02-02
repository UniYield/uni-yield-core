// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault4626Diamond {
    // --- ERC4626 ---
    function asset() external view returns (address);

    function totalAssets() external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    // --- Optional LI.FI-friendly entry ---
    function depositReceived(
        address receiver,
        uint256 minShares,
        uint256 deadline
    ) external returns (uint256 shares, uint256 assetsReceived);

    // --- Strategy registry ---
    function addStrategy(
        bytes32 id,
        address facet,
        uint16 targetBps,
        uint16 maxBps
    ) external;

    function removeStrategy(bytes32 id) external;

    function setStrategyEnabled(bytes32 id, bool enabled) external;

    function setStrategyTargets(
        bytes32[] calldata ids,
        uint16[] calldata targetBps,
        uint16[] calldata maxBps
    ) external;

    // --- Rebalancing ---
    function rebalance() external;

    function previewRebalance()
        external
        view
        returns (bytes32 fromId, bytes32 toId, uint256 assetsToMove);
}
