// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/console2.sol";
import {Setup} from "./utils/Setup.sol";

import {Connector} from "../Connector.sol";

import {YvCurveLpOracle} from "../periphery/YvCurveLpOracle.sol";
import {StableswapOracle} from "../periphery/StableswapOracle.sol";

import {YnVault, ERC20} from "./mocks/YnVault.sol";

contract ConnectorTest is Setup {

    Connector public connector;
    YvCurveLpOracle public yvCurveLpOracle;
    StableswapOracle public stableswapOracle;
    YnVault public vault;

    address public constant TIMELOCK_CONTROLLER = 0xbB73f8a5B0074b27c6df026c77fA08B0111D017A;

    function setUp() public override {
        super.setUp();

        stableswapOracle = new StableswapOracle(address(curveStableswapPool));
        yvCurveLpOracle = new YvCurveLpOracle(address(strategy), address(stableswapOracle));
        vault = new YnVault();
        Connector connectorImpl = new Connector(address(vault), address(yvCurveLpOracle), address(strategy), YNETH, YNLSDE);

        connector = Connector(
            address(
                new TransparentUpgradeableProxy(
                    address(connectorImpl), TIMELOCK_CONTROLLER, ""
                )
            )
        );

        vault.setConnector(address(connector));
        vault.setStrategy(address(strategy));

        connector.initialize(management);
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount > minFuzzAmount && amount < maxFuzzAmount);

        airdrop(ERC20(vault.asset()), user, amount);
        vm.startPrank(user);
        ERC20(vault.asset()).approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();

        uint256 totalAssetsBefore = vault.totalAssets();

        address lp = strategy.asset();
        uint256 totalTokensInLP = ERC20(YNETH).balanceOf(lp) + ERC20(YNLSDE).balanceOf(lp);
        uint256 ynethRatio = ERC20(YNETH).balanceOf(lp) * 1e18 / totalTokensInLP;
        uint256 ynlsdeRatio = 1e18 - ynethRatio;

        vault.swapToYnLsde(amount * ynlsdeRatio / 1e18);
        assertApproxEqRel(vault.totalAssets(), totalAssetsBefore, 1e15, "testDeposit: E0"); // 0.1%

        vault.swapToYnEth(amount * ynethRatio / 1e18);
        assertApproxEqRel(vault.totalAssets(), totalAssetsBefore, 1e15, "testDeposit: E1"); // 0.1%

        totalAssetsBefore = vault.totalAssets();

        // approve
        {
            address[] memory targets = new address[](2);
            uint256[] memory values = new uint256[](2);
            bytes[] memory data = new bytes[](2);
            targets[0] = address(vault.YNLSDE());
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
            uint256 amountB = vault.YNLSDE().balanceOf(address(vault));
            data[0] = abi.encodeWithSignature("deposit(uint256,uint256,uint256)", amountA, amountB, 0);
            vault.processor(targets, values, data);
        }

        assertApproxEqRel(vault.totalAssets(), totalAssetsBefore, 1e11, "testDeposit: E2"); // 0.00001%
    }

    function testWithdraw(uint256 amount) public {
        testDeposit(amount);

        uint256 totalAssetsBefore = vault.totalAssets();

        // approve
        {
            address[] memory targets = new address[](1);
            uint256[] memory values = new uint256[](1);
            bytes[] memory data = new bytes[](1);
            targets[0] = address(strategy);
            data[0] = abi.encodeWithSignature("approve(address,uint256)", address(connector), type(uint256).max);
            vault.processor(targets, values, data);
        }

        // withdraw
        {
            address[] memory targets = new address[](1);
            uint256[] memory values = new uint256[](1);
            bytes[] memory data = new bytes[](1);
            targets[0] = address(connector);
            uint256 shares = strategy.balanceOf(address(vault));
            data[0] = abi.encodeWithSignature("withdraw(uint256,uint256,uint256)", shares, 0, 0);
            vault.processor(targets, values, data);
        }

        assertApproxEqRel(vault.totalAssets(), totalAssetsBefore, 1e11, "testWithdraw: E0"); // 0.00001%
    }
}
