// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategyFacet} from "../vault/IStrategyFacet.sol";

contract MorphoStrategyFacet is IStrategyFacet {
    bytes32 private immutable STRATEGY_ID;

    constructor() {
        STRATEGY_ID = bytes32(uint256(uint160(address(this))));
    }

    function strategyId() external view returns (bytes32) {
        return STRATEGY_ID;
    }

    function totalManagedAssets() external view returns (uint256) {
        // TODO: read Morpho positions and convert to USDC-equivalent using LibVaultStorage.vaultStorage().asset
        return 0;
    }

    function rateBps() external view returns (uint256) {
        // TODO: fetch Morpho supply rate for USDC and convert to bps
        return 0;
    }

    function depositToStrategy(uint256 assets) external {
        assets; // silence unused variable warning
            // TODO: supply USDC to Morpho using stored market addresses
    }

    function withdrawFromStrategy(uint256 assets) external {
        assets; // silence unused variable warning
            // TODO: withdraw USDC from Morpho
    }

    function exitStrategy() external {
        // TODO: unwind all Morpho positions back to idle USDC
    }
}
