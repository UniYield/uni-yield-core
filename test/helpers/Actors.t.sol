// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Test actor addresses for pranking and access control tests.
library Actors {
    address internal constant OWNER = address(0x1);
    address internal constant USER1 = address(0x2);
    address internal constant USER2 = address(0x3);
    address internal constant STRANGER = address(0x999);
}
