// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibVaultStorage {
    bytes32 internal constant STORAGE_SLOT = keccak256("uniyield.vault.storage.v1");

    struct StrategyConfig {
        bool enabled;
        uint16 targetBps;
        uint16 maxBps;
    }

    struct VaultStorage {
        address asset;
        uint8 assetDecimals;
        bool paused;
        string name;
        string symbol;
        uint8 shareDecimals;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        bytes32[] strategyIds;
        mapping(bytes32 => StrategyConfig) strategies;
        bytes32 activeStrategyId;
        uint16 minSwitchBps;
    }

    function vaultStorage() internal pure returns (VaultStorage storage vs) {
        bytes32 position = STORAGE_SLOT;
        assembly {
            vs.slot := position
        }
    }
}
