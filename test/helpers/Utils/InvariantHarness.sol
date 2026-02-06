// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UniYieldDiamond} from "../../../src/UniYieldDiamond.sol";
import {LibVaultStorage} from "../../../src/libraries/LibVaultStorage.sol";

/// @notice Harness exposing vault state and actions for invariant tests. Inherit and bind to diamond.
contract InvariantHarness {
    UniYieldDiamond public diamond;

    function setDiamond(UniYieldDiamond diamond_) internal {
        diamond = diamond_;
    }

    function totalSupply() internal view returns (uint256) {
        (bool ok, bytes memory data) = address(diamond).staticcall(abi.encodeWithSignature("totalSupply()"));
        return ok ? abi.decode(data, (uint256)) : 0;
    }

    function totalAssets() internal view returns (uint256) {
        (bool ok, bytes memory data) = address(diamond).staticcall(abi.encodeWithSignature("totalAssets()"));
        return ok ? abi.decode(data, (uint256)) : 0;
    }

    function balanceOf(address account) internal view returns (uint256) {
        (bool ok, bytes memory data) = address(diamond).staticcall(abi.encodeWithSignature("balanceOf(address)", account));
        return ok ? abi.decode(data, (uint256)) : 0;
    }

    function activeStrategyId() internal view returns (bytes32) {
        (bool ok, bytes memory data) = address(diamond).staticcall(abi.encodeWithSignature("activeStrategyId()"));
        return ok ? abi.decode(data, (bytes32)) : bytes32(0);
    }

    function getStrategyIds() internal view returns (bytes32[] memory) {
        (bool ok, bytes memory data) = address(diamond).staticcall(abi.encodeWithSignature("getStrategyIds()"));
        return ok ? abi.decode(data, (bytes32[])) : new bytes32[](0);
    }
}
