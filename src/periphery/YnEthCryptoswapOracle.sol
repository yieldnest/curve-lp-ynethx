// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {BaseOracle, IChainlinkOracle} from "./BaseOracle.sol";

contract YnEthCryptoswapOracle is BaseOracle {

    string private _description;

    ICurvePool public constant LP = ICurvePool(0x19B8524665aBAC613D82eCE5D8347BA44C714bDd);
    IERC4626 public constant YNETH = IERC4626(0x09db87A538BD693E9d08544577d5cCfAA6373A48);

    constructor() {
        _description = string(abi.encodePacked(LP.name(), " / ETH"));
    }

    function description() external view override returns (string memory) {
        return _description;
    }

    function latestRoundData()
        public
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        int256 lpEthPrice = int256(LP.lp_price() * YNETH.convertToAssets(WAD) / WAD);
        return (0, lpEthPrice, 0, block.timestamp, 0);
    }
}