// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

library LibDiamond {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    error NotContractOwner();
    error InvalidFacetCutAction();
    error FunctionAlreadyExists(bytes4 selector);
    error FunctionDoesNotExist(bytes4 selector);
    error FacetAddressIsZero();
    error FacetHasNoCode();
    error InitializationFunctionReverted(address init, bytes data);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition;
    }

    struct DiamondStorage {
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        address[] facetAddresses;
        mapping(bytes4 => bool) supportedInterfaces;
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function contractOwner() internal view returns (address) {
        return diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        if (msg.sender != diamondStorage().contractOwner) {
            revert NotContractOwner();
        }
    }

    function setSupportedInterface(bytes4 interfaceId, bool supported) internal {
        diamondStorage().supportedInterfaces[interfaceId] = supported;
    }

    function diamondCut(IDiamondCut.FacetCut[] memory facetCuts, address init, bytes memory data) internal {
        for (uint256 i = 0; i < facetCuts.length; i++) {
            IDiamondCut.FacetCut memory cut = facetCuts[i];
            if (cut.action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(cut.facetAddress, cut.functionSelectors);
            } else {
                revert InvalidFacetCutAction();
            }
        }
        emit IDiamondCut.DiamondCut(facetCuts, init, data);
        initializeDiamondCut(init, data);
    }

    function addFunctions(address facetAddress, bytes4[] memory selectors) internal {
        if (facetAddress == address(0)) revert FacetAddressIsZero();
        enforceHasCode(facetAddress);
        DiamondStorage storage ds = diamondStorage();
        uint256 selectorPosition = ds.facetFunctionSelectors[facetAddress].functionSelectors.length;
        if (selectorPosition == 0) {
            ds.facetFunctionSelectors[facetAddress].facetAddressPosition = ds.facetAddresses.length;
            ds.facetAddresses.push(facetAddress);
        }
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 selector = selectors[i];
            if (ds.selectorToFacetAndPosition[selector].facetAddress != address(0)) {
                revert FunctionAlreadyExists(selector);
            }
            ds.facetFunctionSelectors[facetAddress].functionSelectors.push(selector);
            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition(facetAddress, uint96(selectorPosition));
            selectorPosition++;
        }
    }

    function replaceFunctions(address facetAddress, bytes4[] memory selectors) internal {
        if (facetAddress == address(0)) revert FacetAddressIsZero();
        enforceHasCode(facetAddress);
        DiamondStorage storage ds = diamondStorage();
        uint256 selectorPosition = ds.facetFunctionSelectors[facetAddress].functionSelectors.length;
        if (selectorPosition == 0) {
            ds.facetFunctionSelectors[facetAddress].facetAddressPosition = ds.facetAddresses.length;
            ds.facetAddresses.push(facetAddress);
        }
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 selector = selectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacet == address(0)) revert FunctionDoesNotExist(selector);
            if (oldFacet == facetAddress) {
                revert FunctionAlreadyExists(selector);
            }
            removeFunction(oldFacet, selector);
            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition(facetAddress, uint96(selectorPosition));
            ds.facetFunctionSelectors[facetAddress].functionSelectors.push(selector);
            selectorPosition++;
        }
    }

    function removeFunctions(address facetAddress, bytes4[] memory selectors) internal {
        if (facetAddress != address(0)) revert FacetAddressIsZero();
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 selector = selectors[i];
            DiamondStorage storage ds = diamondStorage();
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacet == address(0)) revert FunctionDoesNotExist(selector);
            removeFunction(oldFacet, selector);
        }
    }

    function removeFunction(address facetAddress, bytes4 selector) internal {
        DiamondStorage storage ds = diamondStorage();
        FacetFunctionSelectors storage facetSelectors = ds.facetFunctionSelectors[facetAddress];
        uint256 selectorPosition = ds.selectorToFacetAndPosition[selector].functionSelectorPosition;
        uint256 lastSelectorPosition = facetSelectors.functionSelectors.length - 1;
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = facetSelectors.functionSelectors[lastSelectorPosition];
            facetSelectors.functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        facetSelectors.functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[selector];

        if (facetSelectors.functionSelectors.length == 0) {
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = facetSelectors.facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address init, bytes memory data) internal {
        if (init == address(0)) {
            if (data.length != 0) {
                revert InitializationFunctionReverted(init, data);
            }
            return;
        }
        enforceHasCode(init);
        (bool success, bytes memory error) = init.delegatecall(data);
        if (!success) {
            revert InitializationFunctionReverted(init, error);
        }
    }

    function enforceHasCode(address facetAddress) internal view {
        uint256 size;
        assembly {
            size := extcodesize(facetAddress)
        }
        if (size == 0) revert FacetHasNoCode();
    }
}
