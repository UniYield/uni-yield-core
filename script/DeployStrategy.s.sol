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
            address aavePool = vm.envOr("AAVE_POOL", address(0));
            address aaveAToken = vm.envOr("AAVE_A_TOKEN", address(0));
            AaveStrategyFacet a = new AaveStrategyFacet(aavePool, aaveAToken);
            console.log("AaveStrategyFacet", address(a));
            console.log("AaveStrategyId", uint256(bytes32(uint256(uint160(address(a))))));
        }
        if (keccak256(bytes(which)) == keccak256("compound") || keccak256(bytes(which)) == keccak256("all")) {
            address comet = vm.envOr("COMPOUND_COMET", address(0));
            CompoundStrategyFacet c = new CompoundStrategyFacet(comet);
            console.log("CompoundStrategyFacet", address(c));
            console.log("CompoundStrategyId", uint256(bytes32(uint256(uint160(address(c))))));
        }
        if (keccak256(bytes(which)) == keccak256("morpho") || keccak256(bytes(which)) == keccak256("all")) {
            address morpho = vm.envOr("MORPHO", address(0));
            address loanToken = vm.envOr("MORPHO_LOAN_TOKEN", address(0));
            address collateralToken = vm.envOr("MORPHO_COLLATERAL_TOKEN", address(0));
            address oracle = vm.envOr("MORPHO_ORACLE", address(0));
            address irm = vm.envOr("MORPHO_IRM", address(0));
            uint256 lltv = vm.envOr("MORPHO_LLTV", uint256(0));
            MorphoStrategyFacet m = new MorphoStrategyFacet(morpho, loanToken, collateralToken, oracle, irm, lltv);
            console.log("MorphoStrategyFacet", address(m));
            console.log("MorphoStrategyId", uint256(bytes32(uint256(uint160(address(m))))));
        }

        if (deployerKey != 0) vm.stopBroadcast();
    }
}
