// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibErrors {
    // Access / state
    error NotAuthorized();
    error Paused();
    error ZeroAddress();
    error InvalidArrayLength();
    error InvalidBps();

    // ERC4626 / accounting
    error ZeroAssets();
    error ZeroShares();
    error SlippageExceeded(uint256 expectedMin, uint256 actual);
    error DeadlineExpired(uint256 deadline, uint256 nowTs);

    // Strategy registry
    error StrategyAlreadyExists(bytes32 id);
    error StrategyNotFound(bytes32 id);
    error StrategyDisabled(bytes32 id);
    error StrategyFacetMissing(bytes32 id);
    error AllocationExceedsCap(
        bytes32 id,
        uint256 attemptedBps,
        uint256 maxBps
    );

    // Strategy execution
    error StrategyDepositFailed(bytes32 id);
    error StrategyWithdrawFailed(bytes32 id);
    error StrategyExitFailed(bytes32 id);
    error InsufficientLiquidity(
        bytes32 id,
        uint256 requested,
        uint256 available
    );

    // Rebalancing
    error NoRebalanceNeeded();
    error SwitchThresholdNotMet(
        uint256 currentBps,
        uint256 candidateBps,
        uint256 minImprovementBps
    );

    // External token operations
    error TokenTransferFailed();
    error TokenApprovalFailed();
}
