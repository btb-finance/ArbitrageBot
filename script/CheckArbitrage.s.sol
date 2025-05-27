// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ArbitrageLarry.sol";

contract CheckArbitrageScript is Script {
    ArbitrageLarry public arbitrage;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the arbitrage contract
        arbitrage = new ArbitrageLarry();
        
        console.log("ArbitrageLarry deployed at:", address(arbitrage));
        console.log("KyberSwap Router:", arbitrage.KYBER_ROUTER());
        console.log("Larry DEX:", arbitrage.LARRY_DEX());
        
        vm.stopBroadcast();
        
        // Check arbitrage opportunities for different amounts
        checkOpportunities();
    }
    
    function checkOpportunities() internal view {
        uint256[] memory testAmounts = new uint256[](6);
        testAmounts[0] = 0.001 ether;
        testAmounts[1] = 0.01 ether;
        testAmounts[2] = 0.1 ether;
        testAmounts[3] = 0.5 ether;
        testAmounts[4] = 1 ether;
        testAmounts[5] = 5 ether;
        
        console.log("\n=== ARBITRAGE OPPORTUNITIES CHECK ===");
        console.log("Minimum profit threshold:", arbitrage.minProfitWei());
        console.log("");
        
        for (uint i = 0; i < testAmounts.length; i++) {
            console.log("Checking ETH amount:", testAmounts[i]);
            
            try arbitrage.checkArbitrageOpportunity(testAmounts[i]) returns (
                bool profitableDirection,
                uint256 expectedProfit,
                uint256 larryPriceOnLarry,
                uint256 larryPriceOnKyber
            ) {
                console.log("  Larry tokens on Larry DEX:", larryPriceOnLarry);
                console.log("  Larry tokens on Kyber:", larryPriceOnKyber);
                
                if (expectedProfit > 0) {
                    console.log("  🟢 PROFITABLE!");
                    console.log("  Direction:", profitableDirection ? "Larry DEX -> Kyber" : "Kyber -> Larry DEX");
                    console.log("  Expected profit (ETH):", expectedProfit);
                    console.log("  Expected profit (%):", (expectedProfit * 100) / testAmounts[i]);
                } else {
                    console.log("  🔴 Not profitable");
                }
            } catch {
                console.log("  ❌ Error checking opportunity");
            }
            
            console.log("  ---");
        }
        
        console.log("\n=== USAGE INSTRUCTIONS ===");
        console.log("1. Monitor the output above for profitable opportunities");
        console.log("2. When profit > minimum threshold, execute arbitrage:");
        console.log("   - Call executeArbitrageLarryToKyber() for Larry->Kyber direction");
        console.log("   - Call executeArbitrageKyberToLarry() for Kyber->Larry direction");
        console.log("3. Make sure to provide proper KyberSwap execution parameters");
    }
}