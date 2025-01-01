// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {BaseOracle} from "./BaseOracle.sol";

contract YnEthOracle is BaseOracle {

    IERC4626 constant public YNETH = IERC4626(0x09db87A538BD693E9d08544577d5cCfAA6373A48);

    function description() external pure override returns (string memory) {
        return "ynETH backing value (NOT market price) - ynETH / ETH";
    }

    function latestRoundData()
        public
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, int256(YNETH.convertToAssets(WAD)), 0, block.timestamp, 0);
    }
}