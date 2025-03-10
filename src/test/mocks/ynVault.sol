// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ERC4626, IERC4626, ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {ICurvePool} from "../../interfaces/ICurvePool.sol";

import {Connector} from "../../Connector.sol";

interface IWETH {
    function withdraw(uint wad) external;
}

interface IYNETH is IERC4626 {
    function depositETH(address receiver) external payable returns (uint256 shares);
}

interface IWSTETH is IERC20 {
    function wrap(uint256 _stETHAmount) external returns (uint256);
}

interface ISTETH is IERC20 {
    function getPooledEthByShares(uint256 shares) external view returns (uint256);
}

interface IYNLSDE is IERC4626 {
    function deposit(IERC20 asset, uint256 amount, address receiver) external returns (uint256 shares);
}

interface IYNLSDEViewer {
    function getRate() external view returns (uint256);
}

contract YnVault is ERC4626 {
    Connector public connector;
    IERC20 public strategy;
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IWSTETH public constant WSTETH = IWSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    ISTETH public constant STETH = ISTETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IYNETH public constant YNETH = IYNETH(0x09db87A538BD693E9d08544577d5cCfAA6373A48);
    IYNLSDE public constant YNLSDE = IYNLSDE(0x35Ec69A77B79c255e5d47D5A3BdbEFEfE342630c);
    IYNLSDEViewer public constant YNLSDE_VIEWER = IYNLSDEViewer(0x9B933D84Fac0782F3B275D76B64a0DBf6FBEf28F);
    constructor() ERC4626(WETH) ERC20("YieldNest Vault", "ynVault") {}

    function processor(
        address[] calldata targets,
        uint256[] memory values,
        bytes[] calldata data
    ) external returns (bytes[] memory returnData) {
        uint256 targetsLength = targets.length;
        returnData = new bytes[](targetsLength);

        for (uint256 i = 0; i < targetsLength; i++) {
            (bool success, bytes memory returnData_) = targets[i].call{value: values[i]}(data[i]);
            require(success, "!success");
            returnData[i] = returnData_;
        }
    }

    function swapToYnEth(uint256 amount) external returns (uint256) {
        IWETH(address(WETH)).withdraw(amount);
        return YNETH.depositETH{ value: amount }(address(this));
    }

    function swapToYnLsde(uint256 amount) external returns (uint256) {
        IWETH(address(WETH)).withdraw(amount);
        uint256 _toWrap =
            ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022).exchange{ value: amount }(0, 1, amount, 0); // from WETH to stETH
        STETH.approve(address(WSTETH), _toWrap);
        WSTETH.wrap(_toWrap);
        WSTETH.approve(address(YNLSDE), type(uint256).max);
        return IYNLSDE(YNLSDE).deposit(WSTETH, WSTETH.balanceOf(address(this)), address(this));
    }

    function setConnector(address _connector) external {
        connector = Connector(_connector);
    }

    function setStrategy(address _strategy) external {
        strategy = IERC20(_strategy);
    }

    function totalAssets() public view override returns (uint256) {
        (int256 _rate,) = connector.rate();
        return
            IERC20(asset()).balanceOf(address(this)) +
            (strategy.balanceOf(address(this)) * uint256(_rate) / 1e18) +
            YNETH.convertToAssets(YNETH.balanceOf(address(this))) +
            STETH.balanceOf(address(this)) +
            (WSTETH.balanceOf(address(this)) * STETH.getPooledEthByShares(1e18) / 1e18) +
            (YNLSDE.balanceOf(address(this)) * YNLSDE_VIEWER.getRate() / 1e18);
    }

    receive() external payable {}
}