// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LibReentrancyGuard} from "../libraries/LibReentrancyGuard.sol";
import {IStrategyFacet} from "../interfaces/IStrategyFacet.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract RebalanceFacet {
    event Rebalanced(
        bytes32 indexed fromId, bytes32 indexed toId, uint256 assetsMoved, uint256 fromRate, uint256 toRate
    );

    function rebalance() external {
        LibReentrancyGuard.enter();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        bytes32 currentId = vs.activeStrategyId;
        if (currentId == bytes32(0) || !_strategyExists(currentId)) revert LibErrors.StrategyNotFound(currentId);

        (bytes32 bestId, uint256 bestRate) = _bestEnabledStrategy();
        uint256 currentRate = _strategyRateBps(currentId);

        if (bestId == bytes32(0) || bestId == currentId) revert LibErrors.NoRebalanceNeeded();

        uint256 minSwitch = vs.minSwitchBps;
        if (bestRate <= currentRate || bestRate - currentRate < minSwitch) {
            revert LibErrors.SwitchThresholdNotMet(currentRate, bestRate, minSwitch);
        }

        _delegateToStrategy(currentId, abi.encodeWithSelector(IStrategyFacet.exitStrategy.selector));

        uint256 idleAfter = IERC20(vs.asset).balanceOf(address(this));
        uint256 assetsMoved = idleAfter;
        if (assetsMoved > 0) {
            _delegateToStrategy(bestId, abi.encodeWithSelector(IStrategyFacet.depositToStrategy.selector, assetsMoved));
        }

        vs.activeStrategyId = bestId;
        emit Rebalanced(currentId, bestId, assetsMoved, currentRate, bestRate);
        LibReentrancyGuard.exit();
    }

    function previewRebalance() external view returns (bytes32 fromId, bytes32 toId, uint256 assetsToMove) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        fromId = vs.activeStrategyId;
        if (fromId == bytes32(0) || !_strategyExists(fromId)) {
            return (fromId, bytes32(0), 0);
        }

        (bytes32 bestId, uint256 bestRate) = _bestEnabledStrategy();
        uint256 currentRate = _strategyRateBps(fromId);
        toId = bestId;

        if (bestId == bytes32(0) || bestId == fromId) return (fromId, toId, 0);
        if (bestRate <= currentRate || bestRate - currentRate < vs.minSwitchBps) return (fromId, toId, 0);

        uint256 idle = IERC20(vs.asset).balanceOf(address(this));
        uint256 managed = _strategyTotalManagedAssets(fromId);
        assetsToMove = idle + managed;
    }

    // Internal helpers
    function _strategyFacet(bytes32 id) internal pure returns (address) {
        return address(uint160(uint256(id)));
    }

    function _strategyExists(bytes32 id) internal view returns (bool) {
        if (id == bytes32(0)) return false;
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        bytes32[] storage ids = vs.strategyIds;
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == id) return true;
        }
        return false;
    }

    function _bestEnabledStrategy() internal view returns (bytes32 bestId, uint256 bestRate) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        bytes32[] storage ids = vs.strategyIds;
        for (uint256 i = 0; i < ids.length; i++) {
            bytes32 id = ids[i];
            if (!vs.strategies[id].enabled) continue;
            uint256 rate = _strategyRateBps(id);
            if (rate > bestRate) {
                bestRate = rate;
                bestId = id;
            }
        }
    }

    function _strategyRateBps(bytes32 id) internal view returns (uint256 rate) {
        bytes memory data = abi.encodeWithSelector(IStrategyFacet.rateBps.selector);
        bytes memory result = _staticCallStrategy(id, data);
        rate = abi.decode(result, (uint256));
    }

    function _strategyTotalManagedAssets(bytes32 id) internal view returns (uint256 managed) {
        bytes memory data = abi.encodeWithSelector(IStrategyFacet.totalManagedAssets.selector);
        bytes memory result = _staticCallStrategy(id, data);
        managed = abi.decode(result, (uint256));
    }

    function _delegateToStrategy(bytes32 id, bytes memory data) internal returns (bytes memory result) {
        address facet = _strategyFacet(id);
        if (facet == address(0)) revert LibErrors.StrategyNotFound(id);
        (bool ok, bytes memory returndata) = facet.delegatecall(data);
        if (!ok) revert LibErrors.ExternalCallFailed(id);
        return returndata;
    }

    function _staticCallStrategy(bytes32 id, bytes memory data) internal view returns (bytes memory result) {
        address facet = _strategyFacet(id);
        if (facet == address(0)) revert LibErrors.StrategyNotFound(id);
        (bool ok, bytes memory returndata) = facet.staticcall(data);
        if (!ok) revert LibErrors.ExternalCallFailed(id);
        return returndata;
    }
}
