// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibVaultStorage {
    bytes32 internal constant VAULT_STORAGE_SLOT = keccak256("chainrouter.diamond.vault.storage.v1");

    struct StrategyConfig {
        bool enabled;
        uint16 targetBps; // 0..10000
        uint16 maxBps; // cap
        bytes4 depositSelector; // optional, if using selector-based calls
        bytes4 withdrawSelector; // optional
    }

    struct VaultStorage {
        address asset; // USDC
        uint8 assetDecimals; // cache (6)
        bool paused;
        // Strategy registry
        bytes32[] strategyIds;
        mapping(bytes32 => address) strategyFacet; // id => facet address (optional)
        mapping(bytes32 => StrategyConfig) strategyConfig;
        // ERC20 share state (if you implement yourself)
        string name;
        string symbol;
        uint8 shareDecimals; // likely same as assetDecimals
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
        // Rebalance params
        uint16 minSwitchBps; // e.g. 30 = 0.30% improvement threshold
    }

    function s() internal pure returns (VaultStorage storage vs) {
        bytes32 slot = VAULT_STORAGE_SLOT;
        assembly {
            vs.slot := slot
        }
    }
}
