// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// import "forge-std/console2.sol";

import {Connector} from "../src/Connector.sol";

import {YvCurveLpOracle} from "../src/periphery/YvCurveLpOracle.sol";
import {StableswapOracle} from "../src/periphery/StableswapOracle.sol";

import "forge-std/Script.sol";

// ---- Usage ----
// forge script script/Deploy.s.sol:Deploy --legacy --slow --rpc-url $RPC_URL --broadcast

contract Deploy is Script {

    address sec = 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975;

    address curveStableswapPool = 0x1f59cC10c6360DA918B0235c98E58008452816EB;

    address public constant TIMELOCK_CONTROLLER = 0xbB73f8a5B0074b27c6df026c77fA08B0111D017A;
    address public YEARN_V2_STRAT = 0x823976dA34aC45C23a8DfEa51B3Ff1Ae0D980213;
    address public VAULT = 0x657d9ABA1DBb59e53f9F3eCAA878447dCfC96dCb;
    address public constant YNETH = 0x09db87A538BD693E9d08544577d5cCfAA6373A48;
    address public constant YNLSDE = 0x35Ec69A77B79c255e5d47D5A3BdbEFEfE342630c;

    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        StableswapOracle stableswapOracle = new StableswapOracle(address(curveStableswapPool));
        YvCurveLpOracle yvCurveLpOracle = new YvCurveLpOracle(address(YEARN_V2_STRAT), address(stableswapOracle));
        Connector connectorImpl = new Connector(address(VAULT), address(yvCurveLpOracle), address(YEARN_V2_STRAT), YNETH, YNLSDE);

        Connector connector = Connector(
            address(
                new TransparentUpgradeableProxy(
                    address(connectorImpl), TIMELOCK_CONTROLLER, ""
                )
            )
        );

        connector.initialize(sec);

        vm.stopBroadcast();

        console.log("Connector:", address(connector));
        console.log("stableswapOracle:", address(stableswapOracle));
        console.log("yvCurveLpOracle:", address(yvCurveLpOracle));
    }
}