// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {BaseOracle, IChainlinkOracle} from "./BaseOracle.sol";

contract YvCurveLpOracle is BaseOracle {

    string private _description;

    IERC4626 public immutable YEARN_VAULT;

    IChainlinkOracle public immutable LP_PRICE_ORACLE;

    constructor(address yv, address oracle) {
        YEARN_VAULT = IERC4626(yv);
        LP_PRICE_ORACLE = IChainlinkOracle(oracle);
        _description = string(abi.encodePacked(YEARN_VAULT.name(), " / ETH"));
    }

    function description() external view returns (string memory) {
        return _description;
    }

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

        uint256 assetForShare = YEARN_VAULT.convertToAssets(WAD);

        int256 minPrice =
            int256(price * int256(assetForShare)) /
            int256(10 ** decimals());

        return (roundId, minPrice, startedAt, updatedAt, answeredInRound);
    }
}