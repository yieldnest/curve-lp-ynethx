// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract YnEthRateProvider {
    IERC4626 public constant YNETH = IERC4626(0x09db87A538BD693E9d08544577d5cCfAA6373A48);
    function getRate() external view returns (uint256) {
        uint256 _totalSupply = YNETH.totalSupply();
        uint256 _totalAssets = YNETH.totalAssets();
        if (_totalSupply == 0 || _totalAssets == 0) return 1 ether;
        return 1 ether * _totalAssets / _totalSupply;
    }
}