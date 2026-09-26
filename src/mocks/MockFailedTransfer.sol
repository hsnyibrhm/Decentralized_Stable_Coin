// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { MockERC20 } from "./MockERC20.sol";

contract MockFailedTransfer is MockERC20 {
    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }
}
