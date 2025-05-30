// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/botv4.sol";

contract DeployV4Script is Script {
    ArbitrageLarryV4 public arbitrage;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the V4 arbitrage contract
        arbitrage = new ArbitrageLarryV4();
        
        console.log("ArbitrageLarryV4 deployed at:", address(arbitrage));
        console.log("Universal Router:", arbitrage.UNIVERSAL_ROUTER());
        console.log("Larry DEX:", arbitrage.LARRY_DEX());
        console.log("WETH:", arbitrage.WETH());
        console.log("Current profit sharing - Caller:", arbitrage.callerProfitShare(), "/ 10000");
        
        vm.stopBroadcast();
    }
}