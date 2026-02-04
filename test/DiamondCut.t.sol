// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {UniYieldDiamond} from "../src/UniYieldDiamond.sol";
import {DiamondCutFacet} from "../src/diamond/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/DiamondLoupeFacet.sol";
import {DiamondOwnershipFacet} from "../src/diamond/DiamondOwnershipFacet.sol";

contract DiamondCutTest is Test {
    UniYieldDiamond diamond;
    address owner;

    function setUp() public {
        owner = address(0x1);
        vm.deal(owner, 1 ether);
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new UniYieldDiamond(owner, address(cutFacet));
    }

    function test_AddFacet() public {
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = bytes4(keccak256("supportsInterface(bytes4)"));

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        vm.prank(owner);
        (bool ok, ) = address(diamond).call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector,
                cuts,
                address(0),
                ""
            )
        );
        assertTrue(ok);

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(address(diamond))
            .facets();
        assertEq(facets.length, 2); // cut + loupe
        assertEq(
            IDiamondLoupe(address(diamond)).facetAddress(
                IDiamondLoupe.facets.selector
            ),
            address(loupeFacet)
        );
    }

    function test_RevertWhenNonOwnerCallsDiamondCut() public {
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondLoupe.facets.selector;
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        vm.prank(address(0x999));
        vm.expectRevert();
        address(diamond).call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector,
                cuts,
                address(0),
                ""
            )
        );
    }
}
