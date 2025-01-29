// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IYearnV2Vault} from "../interfaces/IYearnV2Vault.sol";

import {BaseOracle, IChainlinkOracle} from "./BaseOracle.sol";

contract YvCurveLpOracle is BaseOracle {

    string private _description;

    IYearnV2Vault public immutable YEARN_VAULT;

    IChainlinkOracle public immutable LP_PRICE_ORACLE;

    /// @notice Construct the YvCurveLpOracle
    /// @param yv The Yearn vault address
    /// @param oracle The Yearn vault share (pps) oracle address
    constructor(address yv, address oracle) {
        YEARN_VAULT = IYearnV2Vault(yv);
        LP_PRICE_ORACLE = IChainlinkOracle(oracle);
        _description = string(abi.encodePacked(YEARN_VAULT.name(), " / ETH"));
    }

    /// @notice Returns the description of the oracle
    /// @return description
    function description() external view returns (string memory) {
        return _description;
    }

    /// @inheritdoc BaseOracle
    function latestRoundData()
        public
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = LP_PRICE_ORACLE.latestRoundData();

        uint256 assetForShare = YEARN_VAULT.pricePerShare();

        int256 minPrice =
            int256(price * int256(assetForShare)) /
            int256(10 ** decimals());

        return (roundId, minPrice, startedAt, updatedAt, answeredInRound);
    }
}