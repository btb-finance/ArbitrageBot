// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/botv4.sol";

contract SetMinProfitZeroScript is Script {
    // Use the deployed bot from previous test
    ArbitrageLarryV4 constant bot = ArbitrageLarryV4(payable(0x7CB0A5Dc144833c1eB5BF1e3d7A9b850F9ebC51f));
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=== Setting Min Profit to 0 ===");
        console.log("Bot address:", address(bot));
        console.log("Current min profit:", bot.minProfitWei());
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Set minimum profit to 0 (volume mode)
        bot.setMinProfit(0);
        
        vm.stopBroadcast();
        
        console.log("New min profit:", bot.minProfitWei());
        console.log("Min profit set to 0 - Volume mode enabled!");
        
        // Test that trades are now executable even with tiny profits
        console.log("\n=== Testing Volume Mode ===");
        uint256 ethAmount = 0.1 ether;
        uint256 tinyProfit = ethAmount + 1 wei; // Just 1 wei profit
        
        (bool executable, uint256 callerProfit, uint256 ownerProfit) = 
            bot.isTradeExecutable(ethAmount, tinyProfit);
        
        console.log("Trade with 1 wei profit executable:", executable);
        if (executable) {
            console.log("Caller profit:", callerProfit);
            console.log("Owner profit:", ownerProfit);
        }
        
        console.log("Volume mode active - any profit > 0 will execute!");
    }
}