// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AaveStrategyFacet} from "../src/strategies/AaveStrategyFacet.sol";

/// @notice Initializes the vault on an already-deployed diamond and optionally deploys + registers a strategy.
/// Set env: DIAMOND_ADDRESS, ASSET_ADDRESS, VAULT_NAME, VAULT_SYMBOL.
/// Optional: ASSET_DECIMALS (default 6), DECIMALS_OFFSET (default 0), MIN_SWITCH_BPS (default 50).
/// If DEPLOY_STRATEGY=1, deploys AaveStrategyFacet and uses it as the initial strategy.
contract InitVault is Script {
    function run() external {
        address diamond = vm.envAddress("DIAMOND_ADDRESS");
        address asset = vm.envAddress("ASSET_ADDRESS");
        string memory name = vm.envString("VAULT_NAME");
        string memory symbol = vm.envString("VAULT_SYMBOL");
        uint8 assetDecimals = uint8(vm.envOr("ASSET_DECIMALS", uint256(6)));
        uint8 decimalsOffset = uint8(vm.envOr("DECIMALS_OFFSET", uint256(0)));
        uint16 minSwitchBps = uint16(vm.envOr("MIN_SWITCH_BPS", uint256(50)));

        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0));
        address owner = deployerKey != 0 ? vm.addr(deployerKey) : vm.envAddress("CONTRACT_OWNER");
        if (owner == address(0)) owner = address(0x1);

        uint256 deployStrategy = vm.envOr("DEPLOY_STRATEGY", uint256(0));
        bytes32 activeStrategyId;
        if (deployStrategy == 0) {
            activeStrategyId = bytes32(vm.envOr("ACTIVE_STRATEGY_ID", uint256(0)));
            require(
                activeStrategyId != bytes32(0),
                "Set DEPLOY_STRATEGY=1 or ACTIVE_STRATEGY_ID (strategy facet address as uint256)"
            );
        }

        if (deployerKey != 0) vm.startBroadcast(deployerKey);
        if (deployerKey == 0) vm.prank(owner);

        if (deployStrategy != 0) {
            address aavePool = vm.envOr("AAVE_POOL", address(0));
            address aaveAToken = vm.envOr("AAVE_A_TOKEN", address(0));
            AaveStrategyFacet strategy = new AaveStrategyFacet(aavePool, aaveAToken, diamond);
            activeStrategyId = bytes32(uint256(uint160(address(strategy))));
            console.log("AaveStrategyFacet", address(strategy));
        }

        (bool okInit,) = diamond.call(
            abi.encodeWithSignature(
                "initVault(address,uint8,string,string,uint8,uint16,bytes32)",
                asset,
                assetDecimals,
                name,
                symbol,
                decimalsOffset,
                minSwitchBps,
                activeStrategyId
            )
        );
        require(okInit, "initVault failed");

        if (deployStrategy != 0) {
            (bool okAdd,) = diamond.call(
                abi.encodeWithSignature(
                    "addStrategy(bytes32,bool,uint16,uint16)", activeStrategyId, true, uint16(10_000), uint16(10_000)
                )
            );
            require(okAdd, "addStrategy failed");
            (bool okActive,) = diamond.call(abi.encodeWithSignature("setActiveStrategy(bytes32)", activeStrategyId));
            require(okActive, "setActiveStrategy failed");
        }

        if (deployerKey != 0) vm.stopBroadcast();

        console.log("Vault initialized:", name, symbol);
        console.log("Diamond", diamond);
        console.log("Asset", asset);
    }
}
