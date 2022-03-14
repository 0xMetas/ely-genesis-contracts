// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {Vm} from "forge-std/Vm.sol";

import {Owned} from "src/test/mocks/OwnableMock.sol";

contract OwnableTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(2);
    }

    /// @dev Tests that owner can call function with `onlyOwner` modifier.
    function testOwnerCall() public {
        vm.startPrank(users[0]);
        Owned owned = new Owned();

        uint256 prevValue = owned.value();
        uint256 newValue = prevValue + 1;

        owned.setValue(newValue);
        assertEq(newValue, owned.value());
    }

    /// @dev Tests that call
    function testNonOwnerCall() public {
        vm.prank(users[0]);
        Owned owned = new Owned();

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotOwner()"))));
        vm.prank(users[1]);
        owned.setValue(420);
    }
}
