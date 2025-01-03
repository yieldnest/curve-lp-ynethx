// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup} from "./utils/Setup.sol";

import {Connector} from "../Connector.sol";

import {StrategyAprOracle} from "../periphery/StrategyAprOracle.sol";
import {YvCurveLpOracle} from "../periphery/YvCurveLpOracle.sol";
import {YnEthCryptoswapOracle} from "../periphery/YnEthCryptoswapOracle.sol";

import {YnVault, ERC20} from "./mocks/YnVault.sol";

contract ConnectorTest is Setup {

    Connector public connector;
    YvCurveLpOracle public yvCurveLpOracle;
    YnEthCryptoswapOracle public ynEthCryptoswapOracle;
    YnVault public vault;

    address public constant LP = 0x19B8524665aBAC613D82eCE5D8347BA44C714bDd; // yneth/wsteth
    address public constant YNETH = 0x09db87A538BD693E9d08544577d5cCfAA6373A48;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function setUp() public override {
        super.setUp();

        ynEthCryptoswapOracle = new YnEthCryptoswapOracle();
        yvCurveLpOracle = new YvCurveLpOracle(address(strategy), address(ynEthCryptoswapOracle));
        vault = new YnVault();
        connector = new Connector(address(vault), address(yvCurveLpOracle), address(strategy), YNETH, WSTETH);

        vault.setConnector(address(connector));
        vault.setStrategy(address(strategy));

        connector.initialize(management);
    }

    function testDeposit() public {
        uint256 amount = 1 ether;

        airdrop(ERC20(vault.asset()), user, amount);
        vm.startPrank(user);
        ERC20(vault.asset()).approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();

        uint256 totalAssetsBefore = vault.totalAssets();

        uint256 totalTokensInLP = ERC20(YNETH).balanceOf(LP) + ERC20(WSTETH).balanceOf(LP);
        uint256 ynethRatio = ERC20(YNETH).balanceOf(LP) * 1e18 / totalTokensInLP;
        uint256 wstethRatio = 1e18 - ynethRatio;

        vault.swapToWstEth(amount * wstethRatio / 1e18);
        assertApproxEqRel(vault.totalAssets(), totalAssetsBefore, 1e15, "testDeposit: E0"); // 0.1%

        vault.swapToYnEth(amount * ynethRatio / 1e18);
        assertApproxEqRel(vault.totalAssets(), totalAssetsBefore, 1e15, "testDeposit: E1"); // 0.1%

        totalAssetsBefore = vault.totalAssets();

        // approve
        {
            address[] memory targets = new address[](2);
            uint256[] memory values = new uint256[](2);
            bytes[] memory data = new bytes[](2);
            targets[0] = address(vault.WSTETH());
            targets[1] = address(vault.YNETH());
            data[0] = abi.encodeWithSignature("approve(address,uint256)", address(connector), type(uint256).max);
            data[1] = abi.encodeWithSignature("approve(address,uint256)", address(connector), type(uint256).max);
            vault.processor(targets, values, data);
        }

        // deposit
        {
            address[] memory targets = new address[](1);
            uint256[] memory values = new uint256[](1);
            bytes[] memory data = new bytes[](1);
            targets[0] = address(connector);
            uint256 amountA = vault.YNETH().balanceOf(address(vault));
            uint256 amountB = vault.WSTETH().balanceOf(address(vault));
            data[0] = abi.encodeWithSignature("deposit(uint256,uint256,uint256)", amountA, amountB, 0);
            vault.processor(targets, values, data);
        }

        assertApproxEqRel(vault.totalAssets(), totalAssetsBefore, 4e15, "testDeposit: E2"); // 0.4%
    }
}