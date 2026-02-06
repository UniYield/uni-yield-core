// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IDiamondLoupe} from "../../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../../src/interfaces/IERC165.sol";
import {UniYieldDiamond} from "../../src/UniYieldDiamond.sol";
import {DiamondCutFacet} from "../../src/diamond/DiamondCutFacet.sol";
import {DiamondDeployer} from "../helpers/DiamondDeployer.t.sol";
import {Actors} from "../helpers/Actors.t.sol";

contract DiamondLoupeTest is Test, DiamondDeployer {
    UniYieldDiamond diamond;

    function setUp() public {
        vm.deal(Actors.OWNER, 1 ether);
        diamond = deployDiamond(Actors.OWNER);
        vm.startPrank(Actors.OWNER);
        addLoupeFacet(diamond);
        vm.stopPrank();
    }

    function test_Facets() public view {
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(address(diamond)).facets();
        assertEq(facets.length, 2); // cut + loupe
    }

    function test_FacetAddress() public view {
        address cutAddr = IDiamondLoupe(address(diamond)).facetAddress(DiamondCutFacet.diamondCut.selector);
        assertTrue(cutAddr != address(0)); // DiamondCut facet is registered at construction
        bytes4 loupeSelector = IDiamondLoupe.facets.selector;
        address loupeAddr = IDiamondLoupe(address(diamond)).facetAddress(loupeSelector);
        assertTrue(loupeAddr != address(0));
    }

    function test_FacetAddresses() public view {
        address[] memory addrs = IDiamondLoupe(address(diamond)).facetAddresses();
        assertEq(addrs.length, 2);
    }

    function test_FacetFunctionSelectors() public view {
        address[] memory addrs = IDiamondLoupe(address(diamond)).facetAddresses();
        assertTrue(addrs.length >= 1);
        bytes4[] memory selectors = IDiamondLoupe(address(diamond)).facetFunctionSelectors(addrs[1]);
        assertTrue(selectors.length >= 5); // loupe has at least 5
    }

    function test_SupportsInterface() public view {
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IERC165).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IDiamondLoupe).interfaceId));
    }
}
