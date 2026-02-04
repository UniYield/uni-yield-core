// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategyFacet} from "../../src/interfaces/IStrategyFacet.sol";
import {LibVaultStorage} from "../../src/libraries/LibVaultStorage.sol";

/// @notice Minimal strategy facet for tests. No immutables; reads asset from vault storage only when needed.
contract MockStrategyFacet is IStrategyFacet {
    function strategyId() external view override returns (bytes32) {
        return bytes32(uint256(uint160(address(this))));
    }

    function totalManagedAssets() public view override returns (uint256) {
        return 0;
    }

    function rateBps() public view override returns (uint256) {
        return 100; // 1% so rebalance can prefer it over 0
    }

    function depositToStrategy(uint256) public override {
        // No-op: assets stay in vault
    }

    function withdrawFromStrategy(uint256) public override {
        // No-op
    }

    function exitStrategy() public override {
        // No-op
    }

    function strategyDeposit(uint256) external pure override returns (uint256) {
        return 0;
    }

    function strategyWithdraw(
        uint256
    ) external pure override returns (uint256) {
        return 0;
    }

    function strategyTotalAssets() external view override returns (uint256) {
        return totalManagedAssets();
    }

    function strategyRateBps() external view override returns (uint256) {
        return rateBps();
    }

    function strategyExit() external pure override returns (uint256) {
        return 0;
    }
}
