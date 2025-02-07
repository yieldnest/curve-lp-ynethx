// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// import "forge-std/console2.sol";

import {Connector} from "../src/Connector.sol";

import {YvCurveLpOracle} from "../src/periphery/YvCurveLpOracle.sol";
import {StableswapOracle} from "../src/periphery/StableswapOracle.sol";

import {ProxyUtils} from "./utils/ProxyUtils.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/Deploy.s.sol:Deploy --legacy --slow --rpc-url $RPC_URL --broadcast

contract Deploy is Script, ProxyUtils {
    // YnSecurityCouncil
    address sec = 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975;

    // ERC-20: yn-ETH/LSD (yn-ETH/LSD)
    address curveStableswapPool = 0x1f59cC10c6360DA918B0235c98E58008452816EB;

    address public TIMELOCK_CONTROLLER;

    // Curve yn-ETH/LSD Factory yVault as YEARN_V2_STRAT
    address public YEARN_V2_STRAT = 0x823976dA34aC45C23a8DfEa51B3Ff1Ae0D980213;

    // ynETHx as VAULT
    address public VAULT = 0x657d9ABA1DBb59e53f9F3eCAA878447dCfC96dCb;
    address public constant YNETH = 0x09db87A538BD693E9d08544577d5cCfAA6373A48;
    address public constant YNLSDE = 0x35Ec69A77B79c255e5d47D5A3BdbEFEfE342630c;

    function _deployTimelockController(
        uint256 minDelay,
        address proposer1,
        address proposer2,
        address executor1,
        address executor2,
        address admin
    ) internal virtual returns (TimelockController timelock) {
        address[] memory proposers = new address[](2);
        proposers[0] = proposer1;
        proposers[1] = proposer2;

        address[] memory executors = new address[](2);
        executors[0] = executor1;
        executors[1] = executor2;

        timelock = new TimelockController(minDelay, proposers, executors, admin);
    }

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        TimelockController timelock = _deployTimelockController(
            1 days, // minDelay
            sec,    // proposer1 
            sec,    // proposer2
            sec,    // executor1
            sec,    // executor2
            sec     // admin
        );
        TIMELOCK_CONTROLLER = address(timelock);

        StableswapOracle stableswapOracle = new StableswapOracle(address(curveStableswapPool));
        YvCurveLpOracle yvCurveLpOracle = new YvCurveLpOracle(address(YEARN_V2_STRAT), address(stableswapOracle));
        Connector connectorImpl =
            new Connector(address(VAULT), address(yvCurveLpOracle), address(YEARN_V2_STRAT), YNETH, YNLSDE);

        Connector connector =
            Connector(address(new TransparentUpgradeableProxy(address(connectorImpl), TIMELOCK_CONTROLLER, "")));

        connector.initialize(sec);

        vm.stopBroadcast();

        console.log("TimelockController:", TIMELOCK_CONTROLLER);
        console.log("Connector:", address(connector));
        console.log("ProxyAdmin:", getProxyAdmin(address(connector)));
        console.log("Implementation:", getImplementation(address(connector)));
        console.log("connectorImpl:", address(connectorImpl));

        console.log("----------------------------------------");

        console.log("stableswapOracle:", address(stableswapOracle));
        console.log("yvCurveLpOracle:", address(yvCurveLpOracle));
     
        string memory json = string.concat(
            "{\n",
            '  "admin": "', vm.toString(sec), '",\n',
            '  "deployer": "', vm.toString(vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"))), '",\n', 
            '  "stableswapOracle": "', vm.toString(address(stableswapOracle)), '",\n',
            '  "yvCurveLpOracle": "', vm.toString(address(yvCurveLpOracle)), '",\n',
            '  "timelock": "', vm.toString(TIMELOCK_CONTROLLER), '",\n',
            '  "connector-implementation": "', vm.toString(address(connectorImpl)), '",\n',
            '  "connector-proxy": "', vm.toString(address(connector)), '",\n',
            '  "connector-proxyAdmin": "', vm.toString(getProxyAdmin(address(connector))), '"\n',
            "}\n"
        );

        string memory path = string.concat("deployments/connector-", vm.toString(block.chainid), ".json");
        vm.writeFile(path, json);
    }
}
