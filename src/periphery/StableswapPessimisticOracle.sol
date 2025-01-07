// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {BaseOracle, IChainlinkOracle} from "./BaseOracle.sol";

contract StableswapPessimisticOracle is BaseOracle {

    string private _description;

    ICurvePool public immutable LP;
    IChainlinkOracle public immutable COIN1_ORACLE;
    IChainlinkOracle public immutable COIN2_ORACLE;

    constructor(address _curvePool, address _coin1Oracle, address _coin2Oracle) {
        LP = ICurvePool(_curvePool);
        COIN1_ORACLE = IChainlinkOracle(_coin1Oracle);
        COIN2_ORACLE = IChainlinkOracle(_coin2Oracle);
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
        (
            uint80 roundId,
            int256 ethPriceCoin1,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = COIN1_ORACLE.latestRoundData();

        (
            uint80 roundIdCoin2,
            int256 ethPriceCoin2,
            uint256 startedAtCoin2,
            uint256 updatedAtCoin2,
            uint80 answeredInRoundCoin2
        ) = COIN2_ORACLE.latestRoundData();

        int256 minLpEthPrice = ethPriceCoin1 < ethPriceCoin2 ?
            (ethPriceCoin1 * int256(LP.get_virtual_price())) / int256(10 ** decimals()) :
            (ethPriceCoin2 * int256(LP.get_virtual_price())) / int256(10 ** decimals());

        if (updatedAtCoin2 < updatedAt) {
            roundId = roundIdCoin2;
            startedAt = startedAtCoin2;
            updatedAt = updatedAtCoin2;
            answeredInRound = answeredInRoundCoin2;
        }
        return (roundId, minLpEthPrice, startedAt, updatedAt, answeredInRound);
    }
}