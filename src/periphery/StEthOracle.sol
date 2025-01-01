// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IStEth} from "../interfaces/IStEth.sol";

import {BaseOracle} from "./BaseOracle.sol";

contract StEthOracle is BaseOracle {

    IStEth constant public STETH = IStEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    function description() external pure override returns (string memory) {
        return "stETH backing value (NOT market price) - stETH / ETH";
    }

    function latestRoundData()
        public
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, int256(STETH.getPooledEthByShares(WAD)), 0, block.timestamp, 0);
    }
}