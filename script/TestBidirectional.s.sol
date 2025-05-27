// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ArbitrageLarryImproved.sol";

contract TestBidirectionalScript is Script {
    ArbitrageLarryImproved public arbitrage;
    
    function run() external {
        console.log("=== TESTING BIDIRECTIONAL ARBITRAGE BOT ===");
        
        // Deploy the improved arbitrage contract
        arbitrage = new ArbitrageLarryImproved();
        
        console.log("Contract deployed at:", address(arbitrage));
        console.log("Min Profit Threshold:", arbitrage.minProfitWei(), "wei");
        console.log("");
        
        // Test both directions
        testBothDirections();
        
        // Test batch checking
        testBatchChecking();
        
        // Test optimal execution
        testOptimalExecution();
    }
    
    function testBothDirections() internal {
        console.log("=== TESTING BOTH ARBITRAGE DIRECTIONS ===");
        uint256 testAmount = 0.005 ether;
        
        // Test Direction 1: Kyber -> Larry
        console.log("\n--- Direction 1: KyberSwap -> Larry DEX ---");
        try arbitrage.checkKyberToLarryArbitrage(testAmount) returns (
            bool isProfitable1,
            uint256 expectedProfit1,
            uint256 kyberLarryAmount,
            uint256 larryDexEthReturn
        ) {
            console.log("Is Profitable:", isProfitable1);
            console.log("Expected Profit:", expectedProfit1, "wei");
            console.log("KyberSwap LARRY:", kyberLarryAmount);
            console.log("Larry DEX ETH Return:", larryDexEthReturn);
            
            if (isProfitable1) {
                console.log("DIRECTION 1 IS PROFITABLE!");
            }
        } catch {
            console.log("Error checking Kyber->Larry direction");
        }
        
        // Test Direction 2: Larry -> Kyber
        console.log("\n--- Direction 2: Larry DEX -> KyberSwap ---");
        try arbitrage.checkLarryToKyberArbitrage(testAmount) returns (
            bool isProfitable2,
            uint256 expectedProfit2,
            uint256 larryDexLarryAmount,
            uint256 kyberEthReturn
        ) {
            console.log("Is Profitable:", isProfitable2);
            console.log("Expected Profit:", expectedProfit2, "wei");
            console.log("Larry DEX LARRY:", larryDexLarryAmount);
            console.log("KyberSwap ETH Return:", kyberEthReturn);
            
            if (isProfitable2) {
                console.log("DIRECTION 2 IS PROFITABLE!");
            }
        } catch {
            console.log("Error checking Larry->Kyber direction");
        }
        
        // Test Best Direction
        console.log("\n--- OPTIMAL DIRECTION ANALYSIS ---");
        try arbitrage.checkBestArbitrageOpportunity(testAmount) returns (
            bool bestDirection,
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberToLarryProfit,
            uint256 larryToKyberProfit
        ) {
            console.log("Best Direction:", bestDirection ? "Kyber->Larry" : "Larry->Kyber");
            console.log("Is Any Direction Profitable:", isProfitable);
            console.log("Best Expected Profit:", expectedProfit, "wei");
            console.log("Kyber->Larry Profit:", kyberToLarryProfit, "wei");
            console.log("Larry->Kyber Profit:", larryToKyberProfit, "wei");
            
            if (isProfitable) {
                console.log("OPTIMAL ARBITRAGE FOUND!");
                console.log("Bot will automatically choose:", bestDirection ? "Kyber->Larry" : "Larry->Kyber");
            } else {
                console.log("No profitable direction at this amount");
            }
        } catch {
            console.log("Error checking best arbitrage opportunity");
        }
    }
    
    function testBatchChecking() internal {
        console.log("\n=== BATCH CHECKING BOTH DIRECTIONS ===");
        
        uint256[] memory testAmounts = new uint256[](5);
        testAmounts[0] = 0.001 ether;
        testAmounts[1] = 0.005 ether;
        testAmounts[2] = 0.01 ether;
        testAmounts[3] = 0.05 ether;
        testAmounts[4] = 0.1 ether;
        
        try arbitrage.batchCheckBestArbitrage(testAmounts) returns (
            bool[] memory directions,
            bool[] memory profitable,
            uint256[] memory profits
        ) {
            console.log("Amount | Profitable | Best Direction | Profit");
            console.log("-------|------------|----------------|--------");
            
            for (uint i = 0; i < testAmounts.length; i++) {
                console.log("ETH Amount:", testAmounts[i] / 1e15, "milliETH");
                console.log("  Profitable:", profitable[i]);
                console.log("  Best Direction:", directions[i] ? "Kyber->Larry" : "Larry->Kyber");
                console.log("  Profit:", profits[i], "wei");
                
                if (profitable[i]) {
                    console.log("  STATUS: PROFITABLE");
                } else {
                    console.log("  STATUS: Not profitable");
                }
                console.log("  ---");
            }
        } catch {
            console.log("Error in batch checking");
        }
    }
    
    function testOptimalExecution() internal {
        console.log("\n=== OPTIMAL EXECUTION TESTING ===");
        console.log("Note: This tests the logic, not actual execution");
        
        uint256 testAmount = 0.005 ether;
        
        // Check what the optimal execution would do
        try arbitrage.checkBestArbitrageOpportunity(testAmount) returns (
            bool bestDirection,
            bool isProfitable,
            uint256 expectedProfit,
            uint256 kyberToLarryProfit,
            uint256 larryToKyberProfit
        ) {
            console.log("=== EXECUTION PLAN ===");
            console.log("Test Amount:", testAmount);
            console.log("Expected Profit:", expectedProfit, "wei");
            
            if (isProfitable) {
                if (bestDirection) {
                    console.log("EXECUTION: executeOptimalArbitrage() will:");
                    console.log("1. Detect Kyber->Larry is more profitable");
                    console.log("2. Buy", _estimateKyberLarry(testAmount), "LARRY on KyberSwap");
                    console.log("3. Sell LARRY on Larry DEX");
                    console.log("4. Return", expectedProfit, "wei profit to user");
                } else {
                    console.log("EXECUTION: executeOptimalArbitrage() will:");
                    console.log("1. Detect Larry->Kyber is more profitable");
                    console.log("2. Buy LARRY on Larry DEX");
                    console.log("3. Sell LARRY on KyberSwap");
                    console.log("4. Return", expectedProfit, "wei profit to user");
                }
                console.log("5. Take 5% protocol fee automatically");
            } else {
                console.log("EXECUTION: Transaction would revert - not profitable");
            }
        } catch {
            console.log("Error planning optimal execution");
        }
        
        console.log("\n=== BOT FEATURES SUMMARY ===");
        console.log("+ Automatically checks BOTH arbitrage directions");
        console.log("+ Chooses the MOST PROFITABLE direction");
        console.log("+ Executes optimal strategy automatically");
        console.log("+ Batch checks multiple amounts efficiently");
        console.log("+ Provides detailed profit analysis");
        console.log("+ Includes slippage protection");
        console.log("+ Emergency recovery functions");
        console.log("+ Configurable profit thresholds");
    }
    
    function _estimateKyberLarry(uint256 ethAmount) internal returns (uint256) {
        try arbitrage.larryToken().getBuyLARRY(ethAmount) returns (uint256 larryAmount) {
            return (larryAmount * 10100) / 10000; // 1% more
        } catch {
            return 0;
        }
    }
}