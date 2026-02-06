// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Contract that reverts on any call. Useful for testing init failure, facet revert, etc.
contract MockReverter {
    error AlwaysReverts();

    function revertOnCall() external pure {
        revert AlwaysReverts();
    }

    fallback() external payable {
        revert AlwaysReverts();
    }

    receive() external payable {
        revert AlwaysReverts();
    }
}
