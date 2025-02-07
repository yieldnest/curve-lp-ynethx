// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IStEth {
    function getPooledEthByShares(uint256 _shares) external view returns (uint256);
}