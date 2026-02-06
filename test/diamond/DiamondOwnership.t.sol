// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UniYieldDiamond} from "../../src/UniYieldDiamond.sol";
import {DiamondDeployer} from "../helpers/DiamondDeployer.t.sol";
import {Actors} from "../helpers/Actors.t.sol";

interface IOwnership {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

contract DiamondOwnershipTest is Test, DiamondDeployer {
    UniYieldDiamond diamond;

    function setUp() public {
        vm.deal(Actors.OWNER, 1 ether);
        diamond = deployDiamond(Actors.OWNER);
        vm.startPrank(Actors.OWNER);
        addOwnershipFacet(diamond);
        vm.stopPrank();
    }

    function test_Owner() public view {
        assertEq(IOwnership(address(diamond)).owner(), Actors.OWNER);
    }

    function test_TransferOwnership() public {
        vm.prank(Actors.OWNER);
        IOwnership(address(diamond)).transferOwnership(Actors.USER1);
        assertEq(IOwnership(address(diamond)).owner(), Actors.USER1);
    }

    function test_TransferOwnership_RevertsWhenNotOwner() public {
        vm.prank(Actors.USER1);
        vm.expectRevert();
        IOwnership(address(diamond)).transferOwnership(Actors.USER2);
    }

    function test_TransferOwnership_EmitsOwnershipTransferred() public {
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(Actors.OWNER, Actors.USER1);
        vm.prank(Actors.OWNER);
        IOwnership(address(diamond)).transferOwnership(Actors.USER1);
    }
}

event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
