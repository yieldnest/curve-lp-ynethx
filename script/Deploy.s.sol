// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.18;

// import "forge-std/Script.sol";

// // ---- Usage ----
// // forge script script/Deploy.s.sol:Deploy --legacy --slow --rpc-url $RPC_URL --broadcast

// contract Deploy is Script {

//     address sec = 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975;

//     address curveStableswapPool = 0x1f59cC10c6360DA918B0235c98E58008452816EB;

//     address public constant TIMELOCK_CONTROLLER = 0xbB73f8a5B0074b27c6df026c77fA08B0111D017A;

//     function run() external {
//         vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

//         stableswapOracle = new StableswapOracle(address(curveStableswapPool));
//         yvCurveLpOracle = new YvCurveLpOracle(address(strategy), address(stableswapOracle));
//         vault = new YnVault();
//         Connector connectorImpl = new Connector(address(vault), address(yvCurveLpOracle), address(strategy), YNETH, YNLSDE);

//         connector = Connector(
//             address(
//                 new TransparentUpgradeableProxy(
//                     address(connectorImpl), TIMELOCK_CONTROLLER, ""
//                 )
//             )
//         );

//         vault.setConnector(address(connector));
//         vault.setStrategy(address(strategy));

//         connector.initialize(management);

//         vm.stopBroadcast();
//     }
// }