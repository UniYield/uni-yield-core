// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategyFacet} from "../../src/interfaces/IStrategyFacet.sol";

/// @notice Mock strategy that reports a higher rate for rebalance tests.
contract MockStrategyFacetHighRate is IStrategyFacet {
    function strategyId() external view override returns (bytes32) {
        return bytes32(uint256(uint160(address(this))));
    }

    function totalManagedAssets() public pure override returns (uint256) {
        return 0;
    }

    function rateBps() public pure override returns (uint256) {
        return 200; // 2% - higher than MockStrategyFacet (100)
    }

    function depositToStrategy(uint256) public pure override {}

    function withdrawFromStrategy(uint256) public pure override {}

    function exitStrategy() public pure override {}

    function strategyDeposit(uint256) external pure override returns (uint256) {
        return 0;
    }

    function strategyWithdraw(
        uint256
    ) external pure override returns (uint256) {
        return 0;
    }

    function strategyTotalAssets() external pure override returns (uint256) {
        return 0;
    }

    function strategyRateBps() external pure override returns (uint256) {
        return 200;
    }

    function strategyExit() external pure override returns (uint256) {
        return 0;
    }
}
