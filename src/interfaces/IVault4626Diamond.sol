// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";

interface IVault4626Diamond {
    // ERC-20 shares
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // ERC-4626 surface
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    // Strategy management
    function addStrategy(bytes32 id, bool enabled, uint16 targetBps, uint16 maxBps) external;
    function removeStrategy(bytes32 id) external;
    function setStrategyEnabled(bytes32 id, bool enabled) external;
    function setStrategyTargets(bytes32[] calldata ids, uint16[] calldata targetBps, uint16[] calldata maxBps)
        external;
    function setActiveStrategy(bytes32 id) external;

    function activeStrategyId() external view returns (bytes32);
    function getStrategyIds() external view returns (bytes32[] memory);
    function getStrategyConfig(bytes32 id) external view returns (LibVaultStorage.StrategyConfig memory);

    // Rebalance
    function rebalance() external;
    function previewRebalance() external view returns (bytes32 fromId, bytes32 toId, uint256 assetsToMove);

    // Pause (owner only)
    function pause() external;
    function unpause() external;
}
