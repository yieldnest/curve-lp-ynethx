// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {BaseOracle} from "./BaseOracle.sol";

contract StableswapOracle is BaseOracle {

    string private _description;

    ICurvePool public immutable CURVE_POOL;

    /// @notice Construct the StableswapOracle
    /// @param _curvePool The Curve pool address
    constructor(address _curvePool) {
        CURVE_POOL = ICurvePool(_curvePool);
        _description = string(abi.encodePacked(CURVE_POOL.name(), " / ETH Backing price. Assumes backing is 1:1 with ETH"));
    }

    /// @notice Returns the description of the oracle
    /// @return description
    function description() external view override returns (string memory) {
        return _description;
    }

    /// @inheritdoc BaseOracle
    function latestRoundData()
        public
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        uint256 lpPrice = WAD * CURVE_POOL.get_virtual_price() / 10 ** decimals();
        return (0, int256(lpPrice), 0, block.timestamp, 0);
    }
}