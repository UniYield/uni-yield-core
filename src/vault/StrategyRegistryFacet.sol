// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract StrategyRegistryFacet {
    event StrategyAdded(bytes32 indexed id, bool enabled, uint16 targetBps, uint16 maxBps);
    event StrategyRemoved(bytes32 indexed id);
    event StrategyEnabled(bytes32 indexed id, bool enabled);
    event StrategyTargetsUpdated(bytes32 indexed id, uint16 targetBps, uint16 maxBps);
    event ActiveStrategySet(bytes32 indexed id);

    function addStrategy(bytes32 id, bool enabled, uint16 targetBps, uint16 maxBps) external {
        _enforceOwner();
        _validateId(id);
        _validateBps(targetBps, maxBps, id);

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        if (!_strategyExists(id)) {
            vs.strategyIds.push(id);
        }
        vs.strategies[id] = LibVaultStorage.StrategyConfig({enabled: enabled, targetBps: targetBps, maxBps: maxBps});

        emit StrategyAdded(id, enabled, targetBps, maxBps);
    }

    function removeStrategy(bytes32 id) external {
        _enforceOwner();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        (bool found, uint256 index) = _findStrategyIndex(vs.strategyIds, id);
        if (!found) revert LibErrors.StrategyNotFound(id);

        uint256 lastIndex = vs.strategyIds.length - 1;
        if (index != lastIndex) {
            vs.strategyIds[index] = vs.strategyIds[lastIndex];
        }
        vs.strategyIds.pop();
        delete vs.strategies[id];

        if (vs.activeStrategyId == id) {
            vs.activeStrategyId = bytes32(0);
        }

        emit StrategyRemoved(id);
    }

    function setStrategyEnabled(bytes32 id, bool enabled) external {
        _enforceOwner();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        if (!_strategyExists(id)) revert LibErrors.StrategyNotFound(id);
        vs.strategies[id].enabled = enabled;
        emit StrategyEnabled(id, enabled);
    }

    function setStrategyTargets(bytes32[] calldata ids, uint16[] calldata targetBps, uint16[] calldata maxBps)
        external
    {
        _enforceOwner();
        if (ids.length != targetBps.length || ids.length != maxBps.length) revert LibErrors.ArrayLengthMismatch();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        for (uint256 i = 0; i < ids.length; i++) {
            bytes32 id = ids[i];
            if (!_strategyExists(id)) revert LibErrors.StrategyNotFound(id);
            _validateBps(targetBps[i], maxBps[i], id);
            vs.strategies[id].targetBps = targetBps[i];
            vs.strategies[id].maxBps = maxBps[i];
            emit StrategyTargetsUpdated(id, targetBps[i], maxBps[i]);
        }
    }

    function setActiveStrategy(bytes32 id) external {
        _enforceOwner();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        if (!_strategyExists(id)) revert LibErrors.StrategyNotFound(id);
        if (!vs.strategies[id].enabled) revert LibErrors.StrategyDisabled(id);
        vs.activeStrategyId = id;
        emit ActiveStrategySet(id);
    }

    function activeStrategyId() external view returns (bytes32) {
        return LibVaultStorage.vaultStorage().activeStrategyId;
    }

    function getStrategyIds() external view returns (bytes32[] memory) {
        return LibVaultStorage.vaultStorage().strategyIds;
    }

    function getStrategyConfig(bytes32 id) external view returns (LibVaultStorage.StrategyConfig memory) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        if (!_strategyExists(id)) revert LibErrors.StrategyNotFound(id);
        return vs.strategies[id];
    }

    // Internal helpers
    function _enforceOwner() internal view {
        if (msg.sender != LibDiamond.contractOwner()) revert LibErrors.NotAuthorized();
    }

    function _validateId(bytes32 id) internal pure {
        if (address(uint160(uint256(id))) == address(0)) revert LibErrors.ZeroAddress();
    }

    function _validateBps(uint16 targetBps, uint16 maxBps, bytes32 id) internal pure {
        if (targetBps > 10_000 || maxBps > 10_000) revert LibErrors.InvalidBps();
        if (targetBps > maxBps) revert LibErrors.AllocationAboveCap(id, targetBps, maxBps);
    }

    function _strategyExists(bytes32 id) internal view returns (bool) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        (bool found,) = _findStrategyIndex(vs.strategyIds, id);
        return found;
    }

    function _findStrategyIndex(bytes32[] storage ids, bytes32 id) internal view returns (bool found, uint256 index) {
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == id) return (true, i);
        }
        return (false, 0);
    }
}
