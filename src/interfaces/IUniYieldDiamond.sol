// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVault4626Diamond} from "./IVault4626Diamond.sol";
import {IDiamondLoupe} from "./IDiamondLoupe.sol";
import {IDiamondCut} from "./IDiamondCut.sol";
import {IERC165} from "./IERC165.sol";

/// @notice Combined interface for the UniYield Diamond (all facets the frontend may call).
interface IUniYieldDiamond is IVault4626Diamond, IDiamondLoupe, IDiamondCut, IERC165 {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}
