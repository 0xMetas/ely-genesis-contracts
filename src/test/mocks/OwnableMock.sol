// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Ownable} from "src/Ownable.sol";

contract Owned is Ownable {
    uint256 public value = 69;

    function setValue(uint256 newValue) public onlyOwner {
        value = newValue;
    }
}
