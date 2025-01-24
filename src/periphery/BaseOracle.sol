// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IChainlinkOracle} from "../interfaces/IChainlinkOracle.sol";

abstract contract BaseOracle is IChainlinkOracle {

    uint256 constant internal WAD = 1e18;

    /// @notice Returns the number of decimals
    /// @return decimals
    function decimals() public pure returns (uint8) {
        return 18;
    }

    /// @notice Returns the version of the oracle
    /// @return version
    function version() external pure returns (uint256) {
        return 1;
    }

    /// @notice Returns the latest round data
    /// @return roundId, price, startedAt, updatedAt, answeredInRound
    function latestRoundData() public view virtual returns (uint80, int256, uint256, uint256, uint80);

    /// @notice Returns the latest answer
    /// @return price
    function latestAnswer() external view returns (int256) {
        (, int256 price, , , ) = latestRoundData();
        return price;
    }
}