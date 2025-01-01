// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface ICurvePool {
    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external returns (uint256);
    function remove_liquidity_one_coin(uint256 _burn_amount, int128 i, uint256 _min_received, address _receiver) external returns (uint256);
    function get_balances() external view returns (uint256[2] memory);
    function balanceOf(address _account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function coins(uint256 i) external view returns (address);
    function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts, address receiver) external returns (uint256[2] memory);
    function get_virtual_price() external view returns (uint256);
    function name() external view returns (string memory);
}