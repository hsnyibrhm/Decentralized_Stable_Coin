// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract MockV3Aggregator {
    uint8 private immutable i_decimals;
    int256 private s_answer;
    uint80 private s_roundId = 1;
    uint256 private s_updatedAt;
    uint80 private s_answeredInRound = 1;

    constructor(uint8 decimals_, int256 answer_) {
        i_decimals = decimals_;
        s_answer = answer_;
        s_updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (s_roundId, s_answer, s_updatedAt, s_updatedAt, s_answeredInRound);
    }

    function decimals() external view returns (uint8) {
        return i_decimals;
    }

    function updateAnswer(int256 newAnswer) external {
        s_answer = newAnswer;
        s_updatedAt = block.timestamp;
    }

    function updateRoundData(int256 newAnswer, uint80 roundId, uint256 updatedAt, uint80 answeredInRound) external {
        s_answer = newAnswer;
        s_roundId = roundId;
        s_updatedAt = updatedAt;
        s_answeredInRound = answeredInRound;
    }
}
