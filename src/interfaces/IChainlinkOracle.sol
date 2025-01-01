// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IChainlinkOracle {

    function decimals() external view returns (uint8 decimals);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 crvUsdPrice,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestAnswer() external view returns (int256 price);

    function description() external view returns (string memory description);
}