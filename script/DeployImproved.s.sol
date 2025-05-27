// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ArbitrageLarryImproved.sol";

contract DeployImprovedScript is Script {
    ArbitrageLarryImproved public arbitrage;
    
    function run() external {
        console.log("=== DEPLOYING IMPROVED ARBITRAGE CONTRACT ===");
        
        vm.startBroadcast();
        
        // Deploy the improved arbitrage contract
        arbitrage = new ArbitrageLarryImproved();
        
        console.log("ArbitrageLarryImproved deployed at:", address(arbitrage));
        console.log("Owner:", arbitrage.owner());
        console.log("Min Profit:", arbitrage.minProfitWei(), "wei (0.00001 ETH)");
        console.log("Protocol Fee:", arbitrage.protocolFee(), "bps (5%)");
        
        vm.stopBroadcast();
        
        // Test the contract
        testContract();
    }
    
    function testContract() internal {
        console.log("\n=== TESTING IMPROVED CONTRACT ===");
        
        uint256 testAmount = 0.005 ether;
        console.log("Testing with:", testAmount, "ETH");
        
        // Test arbitrage checking
        try arbitrage.checkKyberToLarryArbitrage(testAmount) returns (
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberLarryAmount,
            uint256 larryDexEthReturn
        ) {
            console.log("\n--- Arbitrage Check Results ---");
            console.log("Is Profitable:", isProfitable);
            console.log("Expected Profit:", expectedProfit, "wei");
            console.log("Expected Profit (ETH):", expectedProfit / 1e15, "milliETH");
            console.log("KyberSwap LARRY Amount:", kyberLarryAmount);
            console.log("Larry DEX ETH Return:", larryDexEthReturn);
            
            if (isProfitable) {
                console.log("ARBITRAGE OPPORTUNITY FOUND!");
                console.log("Profit meets minimum threshold");
            } else {
                console.log("No profitable arbitrage at this amount");
            }
        } catch {
            console.log("Error checking arbitrage opportunity");
        }
        
        // Test batch checking
        console.log("\n--- Batch Arbitrage Check ---");
        uint256[] memory testAmounts = new uint256[](5);
        testAmounts[0] = 0.001 ether;
        testAmounts[1] = 0.005 ether;
        testAmounts[2] = 0.01 ether;
        testAmounts[3] = 0.05 ether;
        testAmounts[4] = 0.1 ether;
        
        try arbitrage.batchCheckArbitrage(testAmounts) returns (
            bool[] memory profitable,
            uint256[] memory profits
        ) {
            for (uint i = 0; i < testAmounts.length; i++) {
                console.log("Amount:", testAmounts[i] / 1e15, "milliETH");
                console.log("  Profitable:", profitable[i]);
                console.log("  Profit:", profits[i], "wei");
                if (profitable[i]) {
                    console.log("  PROFITABLE");
                } else {
                    console.log("  Not profitable");
                }
            }
        } catch {
            console.log("Error in batch check");
        }
        
        // Test Larry DEX state
        console.log("\n--- Larry DEX State ---");
        try arbitrage.getLarryDexState() returns (
            uint256 backing,
            uint256 totalSupply,
            uint256 currentPrice
        ) {
            console.log("Backing:", backing, "wei");
            console.log("Total Supply:", totalSupply);
            console.log("Current Price:", currentPrice, "wei per LARRY");
            console.log("Current Price (ETH):", currentPrice / 1e15, "milliETH per LARRY");
        } catch {
            console.log("Error getting Larry DEX state");
        }
        
        console.log("\n=== USAGE INSTRUCTIONS ===");
        console.log("1. Monitor arbitrage opportunities using checkKyberToLarryArbitrage()");
        console.log("2. When profitable, execute using executeKyberToLarryArbitrage()");
        console.log("3. Make sure to provide proper KyberSwap execution parameters");
        console.log("4. Set appropriate slippage protection with minLarryAmount");
        console.log("5. Contract takes 5% protocol fee from profits");
        
        console.log("\n=== CONTRACT FEATURES ===");
        console.log("+ Optimized for KyberSwap -> Larry DEX arbitrage");
        console.log("+ Real-time profitability checking");
        console.log("+ Slippage protection");
        console.log("+ Batch opportunity checking");
        console.log("+ Emergency recovery functions");
        console.log("+ Configurable parameters");
        console.log("+ Gas optimized");
    }
}