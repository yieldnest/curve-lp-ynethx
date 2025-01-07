// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {BaseOracle, IChainlinkOracle} from "./BaseOracle.sol";

contract StableswapOracle is BaseOracle {

    string private _description;

    ICurvePool public immutable LP;

    constructor(address _curvePool) {
        LP = ICurvePool(_curvePool);
        _description = string(abi.encodePacked(LP.name(), " / ETH Backing price. Assumes backing is 1:1 with ETH"));
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
        uint256 lpPrice = WAD * LP.get_virtual_price() / 10 ** decimals();
        return (0, int256(lpPrice), 0, block.timestamp, 0);
    }
}