// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { MockERC20 } from "./MockERC20.sol";

contract MockFailedTransferFrom is MockERC20 {
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}
