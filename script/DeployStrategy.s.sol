// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AaveStrategyFacet} from "../src/strategies/AaveStrategyFacet.sol";
import {CompoundStrategyFacet} from "../src/strategies/CompoundStrategyFacet.sol";
import {MorphoStrategyFacet} from "../src/strategies/MorphoStrategyFacet.sol";

/// @notice Deploys strategy facets. Use the printed strategy id when calling addStrategy / initVault.
/// Env: STRATEGY=aave|compound|morpho|all (default: aave). PRIVATE_KEY optional for dry-run.
contract DeployStrategy is Script {
    function run() external {
        string memory which = vm.envOr("STRATEGY", string("aave"));
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0));
        if (deployerKey != 0) vm.startBroadcast(deployerKey);

        if (keccak256(bytes(which)) == keccak256("aave") || keccak256(bytes(which)) == keccak256("all")) {
            AaveStrategyFacet a = new AaveStrategyFacet();
            console.log("AaveStrategyFacet", address(a));
            console.log("AaveStrategyId", uint256(bytes32(uint256(uint160(address(a))))));
        }
        if (keccak256(bytes(which)) == keccak256("compound") || keccak256(bytes(which)) == keccak256("all")) {
            CompoundStrategyFacet c = new CompoundStrategyFacet();
            console.log("CompoundStrategyFacet", address(c));
            console.log("CompoundStrategyId", uint256(bytes32(uint256(uint160(address(c))))));
        }
        if (keccak256(bytes(which)) == keccak256("morpho") || keccak256(bytes(which)) == keccak256("all")) {
            MorphoStrategyFacet m = new MorphoStrategyFacet();
            console.log("MorphoStrategyFacet", address(m));
            console.log("MorphoStrategyId", uint256(bytes32(uint256(uint160(address(m))))));
        }

        if (deployerKey != 0) vm.stopBroadcast();
    }
}
