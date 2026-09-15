// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract MockV3Aggregator {
    uint8 private immutable i_decimals;
    int256 private s_answer;

    constructor(uint8 decimals_, int256 answer_) {
        i_decimals = decimals_;
        s_answer = answer_;
    }

    function latestRoundData() external view returns (uint80, int256 answer, uint256, uint256, uint80) {
        return (0, s_answer, 0, block.timestamp, 0);
    }

    function decimals() external view returns (uint8) {
        return i_decimals;
    }

    function updateAnswer(int256 newAnswer) external {
        s_answer = newAnswer;
    }
}
