// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Centralized event signatures for test expectEmit. Matches VaultCoreFacet, StrategyRegistryFacet, RebalanceFacet, LibDiamond.
contract Events {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
    event StrategyDeposited(bytes32 indexed strategyId, uint256 assets);
    event StrategyWithdrawn(bytes32 indexed strategyId, uint256 assets);
    event VaultInitialized(
        address asset, string name, string symbol, uint8 shareDecimals, uint16 minSwitchBps, bytes32 activeStrategyId
    );
    event Paused();
    event Unpaused();
    event StrategyAdded(bytes32 indexed id, bool enabled, uint16 targetBps, uint16 maxBps);
    event StrategyRemoved(bytes32 indexed id);
    event StrategyEnabled(bytes32 indexed id, bool enabled);
    event StrategyTargetsUpdated(bytes32 indexed id, uint16 targetBps, uint16 maxBps);
    event ActiveStrategySet(bytes32 indexed id);
    event Rebalanced(
        bytes32 indexed fromId, bytes32 indexed toId, uint256 assetsMoved, uint256 fromRate, uint256 toRate
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
