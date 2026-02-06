// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal Compound V3 Comet interface for base token supply/withdraw.
interface IComet {
    function baseToken() external view returns (address);
    function supplyFrom(address from, address dst, address asset, uint256 amount) external;
    function withdrawFrom(address src, address to, address asset, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function getSupplyRate(uint256 utilization) external view returns (uint64);
    function getUtilization() external view returns (uint256);
}
