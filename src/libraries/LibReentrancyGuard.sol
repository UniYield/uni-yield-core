// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Diamond-safe reentrancy guard using namespaced storage.
library LibReentrancyGuard {
    bytes32 internal constant REENTRANCY_GUARD_SLOT = keccak256("uniyield.reentrancy.guard");

    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;

    error ReentrantCall();

    struct GuardStorage {
        uint256 status;
    }

    function _guard() internal pure returns (GuardStorage storage g) {
        bytes32 slot = REENTRANCY_GUARD_SLOT;
        assembly {
            g.slot := slot
        }
    }

    function enter() internal {
        GuardStorage storage g = _guard();
        if (g.status == _ENTERED) revert ReentrantCall();
        g.status = _ENTERED;
    }

    function exit() internal {
        _guard().status = _NOT_ENTERED;
    }
}
