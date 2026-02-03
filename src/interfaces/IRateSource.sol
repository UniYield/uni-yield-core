// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRateSource {
    function rateBps() external view returns (uint256);
}
