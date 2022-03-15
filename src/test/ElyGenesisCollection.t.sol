// SPDX-License-Identifier: APGL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";

import {ElyGenesisCollection} from "src/ElyGenesisCollection.sol";

contract ElyGenesisCollectionTest is DSTest, stdCheats {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable internal deployer;
    address payable[] internal users;

    ElyGenesisCollection internal elyGenesisCollection;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(4);
        deployer = users[0];

        vm.prank(deployer);
        elyGenesisCollection = new ElyGenesisCollection();
    }

    /// @dev Tests the `purchase` function with fuzzing. Requirements:
    ///   - `purchase` doesn't revert
    ///   - `totalSupplyAll` matches the amount fuzzed
    ///   - `balanceOf(user, id)` matches the supply of each ID
    function testPurchase(uint16 amount) public {
        // Ignore amounts greater than maximum supply
        if (amount > elyGenesisCollection.MAX_SUPPLY()) return;

        // Switch to deployer account to enable purchases
        vm.prank(deployer);
        elyGenesisCollection.setPurchaseable(true);

        // Switch to user to start purchasing
        startHoax(users[1], users[1], type(uint256).max);

        uint256 price = elyGenesisCollection.PRICE();
        uint256 txLimit = elyGenesisCollection.transactionLimit();
        uint256 numLoops = amount / txLimit;

        // Purchase maximum per transaction for efficiency
        for (uint256 i = 0; i < numLoops; ++i) {
            elyGenesisCollection.purchase{value: price * txLimit}(txLimit);
        }

        // Purchase any leftover (when `amount` isn't a multiple of `txLimit`)
        uint256 remaining = amount - (numLoops * txLimit);
        if (remaining > 0)
            elyGenesisCollection.purchase{value: price * remaining}(remaining);

        assertEq(elyGenesisCollection.totalSupplyAll(), amount);

        // Verify that the users balance of each token is equal to the amount purchased
        for (uint256 i = 0; i < 5; ++i) {
            uint256 balance = elyGenesisCollection.balanceOf(users[1], i);
            uint256 supply = elyGenesisCollection.totalSupply(i);
            assertEq(balance, supply);
        }
    }

    /// @dev Tests the `withdrawEth` function. Requirements:
    ///   - revert when called by non-owner
    ///   - send expected amount to owner
    function testWithdrawal() public {
        // Switch to deployer account to enable purchases
        vm.prank(deployer);
        elyGenesisCollection.setPurchaseable(true);

        // Switch to user to purchase
        startHoax(users[1]);

        uint256 amount = elyGenesisCollection.transactionLimit();
        uint256 price = amount * elyGenesisCollection.PRICE();

        elyGenesisCollection.purchase{value: price}(amount);

        // Verify withdrawal as non-owner reverts
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotOwner()"))));
        elyGenesisCollection.withdrawEth();

        vm.stopPrank();
        uint256 balance = deployer.balance;

        // Switch back to deployer to withdraw
        vm.prank(deployer);
        elyGenesisCollection.withdrawEth();

        // Verify deployer balance is increased by the expected amount
        assertEq(deployer.balance, balance + price);
    }
}
