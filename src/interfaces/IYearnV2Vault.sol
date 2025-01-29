// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IYearnV2Vault {
    function deposit(uint256 _amount, address recipient) external returns (uint256);
    function withdraw(uint256 maxShares, address recipient) external returns (uint256);
    function token() external view returns (address);
    function pricePerShare() external view returns (uint256);
    function name() external view returns (string memory);
}