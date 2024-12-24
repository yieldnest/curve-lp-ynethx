// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICurvePool} from "./interfaces/ICurvePool.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

contract Connector {
    using SafeERC20 for IERC20;

    address public immutable xvault;

    IStrategyInterface public immutable strategy;

    ICurvePool public immutable curvePool;

    IERC20 public immutable assetA;
    IERC20 public immutable assetB;

    constructor(address _xvault, address _strategy, address _assetA, address _assetB) { // @todo - add sanity checks
        xvault = _xvault;
        strategy = IStrategyInterface(_strategy);
        assetA = IERC20(_assetA);
        assetB = IERC20(_assetB);
        curvePool = ICurvePool(strategy.asset());
        // @todo - approvals
    }

    function rate() external view returns (uint256) {
        // return strategy.rate();
        // @todo - use pessimistic oracle
    }

    function deposit(uint256 _amount, uint256 _split, uint256 _minOut) external returns (uint256) {
        require(_amount > 0, "!amount");
        require(_split <= 100, "!split");

        if (_split > 0) {
            uint256 _amountA = _amount * _split / 100;
            uint256 _amountB = _amount - amountA;
            if (amountA > 0) assetA.safeTransferFrom(msg.sender, address(this), _amountA);
            if (amountB > 0) assetB.safeTransferFrom(msg.sender, address(this), _amountB);
        }

        curvePool.add_liquidity(_amounts, _minOut);

        return strategy.deposit(curvePool.balanceOf(address(this)), xvault);
    }

    function withdraw(uint256 _amount, uint256 _minOut, bool _tokenA) external {
        require(_amount > 0, "!amount");
        require(_split <= 100, "!split");

        strategy.redeem(_amount, address(this), xvault, 0);

        return curvePool.remove_liquidity_one_coin(_amount, 0, 0, address(this)); // @todo - handles params correctly
    }

    // function sweep(address _token) // @todo
}