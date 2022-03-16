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

    event PermanentURI(string uri, uint256 indexed id);

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

    /// @dev Tests the `setBaseUri` function. Requirements:
    ///   - revert when called by non-owner
    function testSetUriNonOwner() public {
        // Verify that updates to base URI as non-owner revert.
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotOwner()"))));
        vm.prank(users[1]);
        elyGenesisCollection.setBaseUri("test_uri");
    }

    /// @dev Test the `setBaseUri` and `uri` functions. Requirements:
    ///   - update correctly when called by owner
    ///   - generate correct URI based on the token ID
    function testGetUri() public {
        // Verify that base URI gets updated correctly as owner
        vm.prank(deployer);
        elyGenesisCollection.setBaseUri("ipfs://test/");

        // Verify the token URI is returned in the correct format
        startHoax(users[1]);

        string memory uri;
        uri = elyGenesisCollection.uri(0);
        assertEq(uri, "ipfs://test/0.json");

        uri = elyGenesisCollection.uri(3);
        assertEq(uri, "ipfs://test/3.json");
    }

    /// @dev Test the `freezeMetadata` function. Requirements:
    ///   - revert when called by non-owner
    ///   - emit PermanentURI event for each token ID when called
    ///   - revert if URI is modified after freeze
    function testFreezeMetadata() public {
        // Verify non-owner cannot freeze metadata
        vm.prank(users[1]);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("NotOwner()"))));
        elyGenesisCollection.freezeMetadata();

        // Switch to owner
        startHoax(deployer);

        // Set URI
        elyGenesisCollection.setBaseUri("ipfs://test/");

        string[5] memory uris = [
            elyGenesisCollection.uri(0),
            elyGenesisCollection.uri(1),
            elyGenesisCollection.uri(2),
            elyGenesisCollection.uri(3),
            elyGenesisCollection.uri(4)
        ];

        // Set up the expected events
        for (uint256 i = 0; i < 5; ++i) {
            vm.expectEmit(true, false, false, true);
            emit PermanentURI(uris[i], i);
        }

        // Freeze the metadata
        elyGenesisCollection.freezeMetadata();

        // Verify the metadata cannot be updated
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("FrozenMetadata()")))
        );
        elyGenesisCollection.setBaseUri("ipfs://fake");
    }
}
