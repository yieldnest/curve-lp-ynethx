// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {StrategyConvexStaker, ERC20} from "src/StrategyConvexStaker.sol";
import {IStrategyInterface} from "src/interfaces/IStrategyInterface.sol";
import {IConvexBooster} from "src/interfaces/ConvexInterfaces.sol";
import {ICurvePool} from "../../interfaces/ICurvePool.sol";
import {ICurveStableswapNGFactory} from "../../interfaces/ICurveStableswapNGFactory.sol";

// Inherit the events so they can be checked if desired.
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

interface IFactory {
    function governance() external view returns (address);

    function set_protocol_fee_bps(uint16) external;

    function set_protocol_fee_recipient(address) external;
}

// Heroglyph pools
// Porigon - Polygon
//
// https://app.balancer.fi/#/polygon/pool/0x7c173e2a341faf5c90bf0ff448cd925d3731c604000200000000000000000eb8
//
// Kabosuchan - Base
//
// https://app.balancer.fi/#/base/pool/0x0dce7d1e1fbfc85c31bd04f890027738f00e580b000100000000000000000163
//
// OogaBooga - Arbitrum
//
// https://app.balancer.fi/#/arbitrum/pool/0xd2b6e489ce64691cb46967df6963a49f92764ba9000200000000000000000545
//
// Molandak - Arbitrum
//
// https://app.balancer.fi/#/arbitrum/pool/0xfed111077e0905ef2b2fbf3060cfa9a34bab4383000200000000000000000544

contract Setup is ExtendedTest, IEvents {
    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public strategy;
    ICurvePool public curveStableswapPool = ICurvePool(0x1f59cC10c6360DA918B0235c98E58008452816EB);

    // to use when deploying strategy
    IConvexBooster public booster; // specific to each chain
    uint256 public pid; // specific to each pool
    string public name;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    // Fuzz from $0.01 of 1e6 stable coins up to 1 trillion of a 1e18 coin
    uint256 public maxFuzzAmount = 100 ether;
    uint256 public minFuzzAmount = 1_000_000_000;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    address public constant YNETH = 0x09db87A538BD693E9d08544577d5cCfAA6373A48;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant YNLSDE = 0x35Ec69A77B79c255e5d47D5A3BdbEFEfE342630c;
    address public constant YNLSDE_VIEWER = 0x9B933D84Fac0782F3B275D76B64a0DBf6FBEf28F;
    address public constant YNETH_VIEWER = 0xF0207Ffa0b793E009DF9Df62fEE95B8FC6c93EcF;

    ICurveStableswapNGFactory public constant FACTORY =
        ICurveStableswapNGFactory(0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf);

    function setUp() public virtual {
        //uint256 mainnetFork = vm.createFork("mainnet");
        //uint256 arbitrumFork = vm.createFork("arbitrum");
        //uint256 polygonFork = vm.createFork("polygon");
        //uint256 optimismFork = vm.createFork("optimism");

        //vm.selectFork(mainnetFork);
        //vm.selectFork(arbitrumFork);
        //vm.selectFork(polygonFork);
        //vm.selectFork(optimismFork);

        // _deployStableswapPool();
        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["ynETH/ynLSDe"]);

        // Set decimals
        decimals = asset.decimals();

        // setup vars for strategy
        booster = IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31); // convex mainnet booster: 0xF403C135812408BFbE8713b5A23a04b3D48AAE31
        pid = 417; // convex mainnet tricrypto: 188, MIM: 40, yneth: 381
        name = "StrategyConvexMIM";

        // Deploy strategy and set variables
        strategy = IStrategyInterface(setUpStrategy());

        factory = strategy.FACTORY();

        // label all the used addresses for traces
        vm.label(user, "user");
        vm.label(address(booster), "booster");
        vm.label(keeper, "keeper");
        vm.label(address(asset), "asset");
        vm.label(management, "management");
        vm.label(address(strategy), "strategy");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
    }

    function setUpStrategy() public returns (address) {

        // pid = IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31).poolLength();
        // address _gauge = 0xc58faAf6eAc90bbCAD725d700efF613116393DE9;
        // vm.prank(0x5F47010F230cE1568BeA53a06eBAF528D05c5c1B);
        // IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31).addPool(address(curveStableswapPool), _gauge, 3);

        // we save the strategy as a IStrategyInterface to give it the needed interface
        IStrategyInterface _strategy = IStrategyInterface(
            address(
                new StrategyConvexStaker(
                    address(asset),
                    pid,
                    address(booster),
                    name
                )
            )
        );

        // set keeper
        _strategy.setKeeper(keeper);
        // set treasury
        _strategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        // set management of the strategy
        _strategy.setPendingManagement(management);

        vm.prank(management);
        _strategy.acceptManagement();

        return address(_strategy);
    }

    function depositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public {
        uint256 _assets = _strategy.totalAssets();
        uint256 _balance = ERC20(_strategy.asset()).balanceOf(
            address(_strategy)
        );
        uint256 _idle = _balance > _assets ? _assets : _balance;
        uint256 _debt = _assets - _idle;
        assertEq(_assets, _totalAssets, "!totalAssets");
        assertEq(_debt, _totalDebt, "!totalDebt");
        assertEq(_idle, _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(ERC20 _asset, address _to, uint256 _amount) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function setFees(uint16 _protocolFee, uint16 _performanceFee) public {
        address gov = IFactory(factory).governance();

        // Need to make sure there is a protocol fee recipient to set the fee.
        vm.prank(gov);
        IFactory(factory).set_protocol_fee_recipient(gov);

        vm.prank(gov);
        IFactory(factory).set_protocol_fee_bps(_protocolFee);

        vm.prank(management);
        strategy.setPerformanceFee(_performanceFee);
    }

    function _deployStableswapPool() internal {
        // // deploy Curve StableswapNG pool
        address[] memory coins = new address[](2);
        coins[0] = address(YNETH);
        coins[1] = address(YNLSDE);
        uint8[] memory assetTypes = new uint8[](2); // 1: Oracle - token with rate oracle (e.g. wstETH)
        assetTypes[0] = 1;
        assetTypes[1] = 1;
        bytes4[] memory methodIds = new bytes4[](2);
        methodIds[0] = bytes4(keccak256("getRate()"));
        methodIds[1] = bytes4(keccak256("getRate()"));
        address[] memory oracles = new address[](2);
        oracles[0] = YNETH_VIEWER;
        oracles[1] = YNLSDE_VIEWER;
        curveStableswapPool = FACTORY.deploy_plain_pool(
            "ynMAXI", // name
            "ynMAXI", // symbol
            coins,
            200, // A
            1000000, // fee
            20000000000, // _offpeg_fee_multiplier
            866, // _ma_exp_time
            0, // implementation id
            assetTypes,
            methodIds,
            oracles
        );

        _addLiquidity();
    }

    function _addLiquidity() internal {
        uint256 amount = 1 ether;
        address seeder = address(0x123);
        airdrop(ERC20(YNETH), seeder, amount);
        airdrop(ERC20(YNLSDE), seeder, amount);

        vm.startPrank(seeder);
        ERC20(YNETH).approve(address(curveStableswapPool), amount);
        ERC20(YNLSDE).approve(address(curveStableswapPool), amount);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;
        curveStableswapPool.add_liquidity(amounts, 0);
        vm.stopPrank();
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokenAddrs["3CryptoUSDT"] = 0xf5f5B97624542D72A9E06f04804Bf81baA15e2B4;
        tokenAddrs["MIM-3Crv"] = 0x5a6A4D54456819380173272A5E8E9B9904BdF41B;
        tokenAddrs["ynETH/wstETH"] = 0x19B8524665aBAC613D82eCE5D8347BA44C714bDd;
        tokenAddrs["ynETH/ynLSDe"] = address(curveStableswapPool);
    }
}
