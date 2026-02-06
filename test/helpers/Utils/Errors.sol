// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibErrors} from "../../../src/libraries/LibErrors.sol";
import {LibDiamond} from "../../../src/libraries/LibDiamond.sol";

/// @notice Error helpers for test expectRevert. Re-exports LibErrors and LibDiamond errors.
contract Errors {
    function notAuthorized() internal pure {
        revert LibErrors.NotAuthorized();
    }

    function paused() internal pure {
        revert LibErrors.Paused();
    }

    function zeroAddress() internal pure {
        revert LibErrors.ZeroAddress();
    }

    function invalidBps() internal pure {
        revert LibErrors.InvalidBps();
    }

    function zeroAssets() internal pure {
        revert LibErrors.ZeroAssets();
    }

    function zeroShares() internal pure {
        revert LibErrors.ZeroShares();
    }

    function strategyNotFound(bytes32 id) internal pure {
        revert LibErrors.StrategyNotFound(id);
    }

    function strategyDisabled(bytes32 id) internal pure {
        revert LibErrors.StrategyDisabled(id);
    }

    function alreadyInitialized() internal pure {
        revert LibErrors.AlreadyInitialized();
    }

    function notContractOwner() internal pure {
        revert LibDiamond.NotContractOwner();
    }

    function functionAlreadyExists(bytes4 selector) internal pure {
        revert LibDiamond.FunctionAlreadyExists(selector);
    }

    function functionDoesNotExist(bytes4 selector) internal pure {
        revert LibDiamond.FunctionDoesNotExist(selector);
    }
}
